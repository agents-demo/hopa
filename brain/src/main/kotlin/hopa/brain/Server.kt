package hopa.brain

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.nio.file.Files
import java.nio.file.Path
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

data class DecisionRequest(
    val goal: String,
    val installed: List<Pair<String, String>> = emptyList(),
    val sessionId: String? = null,
)

/**
 * The first brain service slice. It decides where to start, not how to finish:
 * the model-driven loop is still on the PC. Payment always hands over.
 */
class BrainService(
    private val store: KnowledgeStore,
    private val entries: List<KnowledgeEntry>,
    private val version: String = "0.1.0",
) {
    private val sessions = mutableMapOf<String, MutableList<Map<String, Any?>>>()

    fun decide(request: DecisionRequest): Map<String, Any?> {
        val sessionId = request.sessionId ?: UUID.randomUUID().toString()
        val matches = store.matchTask(request.goal, limit = 2, installed = request.installed)

        val decision: Map<String, Any?> = when {
            isPayment(request.goal) -> mapOf(
                "action" to null,
                "say" to "Payment needs your approval.",
                "done" to false,
                "needUser" to true,
            )

            matches.isEmpty() -> mapOf(
                "action" to null,
                "say" to "I do not know which app to use. Please choose.",
                "done" to false,
                "needUser" to true,
                "options" to entries.map { it.display }.take(8),
            )

            matches.size > 1 -> mapOf(
                "action" to null,
                "say" to "Which one?",
                "done" to false,
                "needUser" to true,
                "options" to matches.map { it.display },
            )

            else -> {
                val entry = matches.first()
                val bundle = entry.packages.firstOrNull()
                if (bundle == null) {
                    mapOf(
                        "action" to null,
                        "say" to "No app bundle for ${entry.display}; the web channel is next.",
                        "done" to false,
                        "needUser" to true,
                    )
                } else {
                    mapOf(
                        "action" to mapOf(
                            "schemaVersion" to "1",
                            "kind" to "ui.launch",
                            "app" to bundle,
                            "timeoutMs" to 10000,
                        ),
                        "say" to "Opening ${entry.display}.",
                        "done" to false,
                        "needUser" to false,
                    )
                }
            }
        }

        val enriched = decision + mapOf("sessionId" to sessionId, "version" to version)
        sessions.getOrPut(sessionId) { mutableListOf() }.add(enriched)
        return enriched
    }

    fun session(id: String): List<Map<String, Any?>>? = sessions[id]

    fun entries(): List<KnowledgeEntry> = entries

    fun search(query: String): List<KnowledgeEntry> = store.matchTask(query, limit = 10)

    private fun isPayment(text: String): Boolean {
        val lowered = text.lowercase()
        return listOf("pay", "payment", "checkout", "支付", "付款", "结算").any {
            lowered.contains(it)
        }
    }
}

class BrainServer(
    private val service: BrainService,
    private val port: Int = 8731,
    private val verbose: Boolean = true,
) {
    private val gson = Gson()
    private lateinit var server: HttpServer
    private var executor: ExecutorService? = null

    fun start(): Int {
        server = HttpServer.create(InetSocketAddress("127.0.0.1", port), 0)
        server.createContext("/health") { exchange ->
            respond(exchange, 200, mapOf("status" to "ok"))
        }
        server.createContext("/version") { exchange ->
            respond(exchange, 200, mapOf("version" to "0.1.0", "contract" to "1"))
        }
        server.createContext("/decide") { exchange -> handleDecide(exchange) }
        server.createContext("/knowledge") { exchange -> handleKnowledge(exchange) }
        server.createContext("/session/") { exchange -> handleSession(exchange) }
        val pool = Executors.newFixedThreadPool(4) { runnable ->
            Thread(runnable).apply { isDaemon = true }
        }
        executor = pool
        server.executor = pool
        server.start()
        return server.address.port
    }

    fun stop() {
        if (::server.isInitialized) server.stop(0)
        executor?.shutdownNow()
    }

    private fun handleDecide(exchange: HttpExchange) {
        if (exchange.requestMethod != "POST") {
            respond(exchange, 405, mapOf("error" to "POST required"))
            return
        }
        val traceId = exchange.requestHeaders.getFirst("X-Trace-Id") ?: UUID.randomUUID().toString()
        try {
            val body = exchange.requestBody.readBytes().toString(Charsets.UTF_8)
            val root = JsonParser.parseString(body).asJsonObject
            val request = DecisionRequest(
                goal = root.stringOr("goal", ""),
                installed = installedFrom(root),
                sessionId = root.get("sessionId")?.asString,
            )
            val decision = service.decide(request)
            log(traceId, "decide", mapOf("sessionId" to decision["sessionId"], "goal" to request.goal))
            respond(exchange, 200, decision)
        } catch (exc: Exception) {
            log(traceId, "error", mapOf("message" to (exc.message ?: exc.javaClass.simpleName)))
            respond(exchange, 400, mapOf("error" to "invalid request"))
        }
    }

    private fun handleKnowledge(exchange: HttpExchange) {
        if (exchange.requestMethod != "GET") {
            respond(exchange, 405, mapOf("error" to "GET required"))
            return
        }
        val query = exchange.requestURI.query ?: ""
        val raw = query.split("&")
            .firstOrNull { it.startsWith("q=") }
            ?.substring(2)
            ?: ""
        val text = URLDecoder.decode(raw, "UTF-8")
        val matches = if (text.isBlank()) service.entries() else service.search(text)
        val payload = matches.map { entry ->
            mapOf(
                "name" to entry.name,
                "display" to entry.display,
                "bundle" to (entry.packages.firstOrNull() ?: ""),
            )
        }
        respond(exchange, 200, mapOf("entries" to payload))
    }

    private fun handleSession(exchange: HttpExchange) {
        if (exchange.requestMethod != "GET") {
            respond(exchange, 405, mapOf("error" to "GET required"))
            return
        }
        val id = exchange.requestURI.path.removePrefix("/session/")
        val decisions = service.session(id)
        if (decisions == null) {
            respond(exchange, 404, mapOf("error" to "unknown session"))
        } else {
            respond(exchange, 200, mapOf("sessionId" to id, "decisions" to decisions))
        }
    }

    private fun installedFrom(root: JsonObject): List<Pair<String, String>> {
        val settings = root.getAsJsonObject("settings") ?: return emptyList()
        val array = settings.getAsJsonArray("installed") ?: return emptyList()
        val result = mutableListOf<Pair<String, String>>()
        for (element in array) {
            val item = element.asJsonObject
            val bundle = item.stringOr("bundle", "")
            if (bundle.isEmpty()) continue
            result.add(bundle to item.stringOr("label", bundle))
        }
        return result
    }

    private fun JsonObject.stringOr(key: String, fallback: String): String =
        get(key)?.takeIf { !it.isJsonNull }?.asString ?: fallback

    private fun respond(exchange: HttpExchange, status: Int, payload: Any?) {
        val bytes = gson.toJson(payload).toByteArray(Charsets.UTF_8)
        exchange.responseHeaders.add("Content-Type", "application/json; charset=utf-8")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }

    private fun log(traceId: String, event: String, fields: Map<String, Any?>) {
        if (!verbose) return
        val payload = mapOf(
            "ts" to Instant.now().toString(),
            "event" to event,
            "traceId" to traceId,
        ) + fields
        System.err.println(gson.toJson(payload))
    }
}

fun main(args: Array<String>) {
    val port = args.firstOrNull()?.toIntOrNull() ?: 8731
    val knowledgeDir = Path.of(args.getOrNull(1) ?: "brain/knowledge/apps")
    val entries = if (Files.exists(knowledgeDir)) {
        KnowledgeLoader.load(knowledgeDir).map { it.entry }
    } else {
        DemoEntries.all
    }
    val service = BrainService(KnowledgeStore(entries), entries)
    val server = BrainServer(service, port)
    val actual = server.start()
    println("hopa-brain listening on http://127.0.0.1:$actual")
    Runtime.getRuntime().addShutdownHook(Thread { server.stop() })
    Thread.currentThread().join()
}
