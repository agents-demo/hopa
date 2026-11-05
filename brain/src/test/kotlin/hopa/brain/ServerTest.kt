package hopa.brain

import com.google.gson.JsonParser
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

private var passed = 0

private fun check(condition: Boolean, message: String) {
    if (!condition) throw AssertionError(message)
    passed++
}

fun main() {
    val entries = DemoEntries.all
    val server = BrainServer(BrainService(KnowledgeStore(entries), entries), 0, verbose = false)
    val port = server.start()
    val client = HttpClient.newHttpClient()

    fun post(body: String): Pair<Int, String> {
        val request = HttpRequest.newBuilder(URI("http://127.0.0.1:$port/decide"))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()
        val response = client.send(request, HttpResponse.BodyHandlers.ofString())
        return response.statusCode() to response.body()
    }

    fun get(path: String): Pair<Int, String> {
        val request = HttpRequest.newBuilder(URI("http://127.0.0.1:$port$path")).GET().build()
        val response = client.send(request, HttpResponse.BodyHandlers.ofString())
        return response.statusCode() to response.body()
    }

    try {
        val health = get("/health")
        check(health.first == 200 && health.second.contains("\"ok\""), "health endpoint")

        val version = get("/version")
        check(version.first == 200 && version.second.contains("\"contract\""), "version endpoint")

        val settings = post(
            """{"goal":"打开设置","settings":{"installed":[{"bundle":"com.huawei.hmos.settings","label":"Settings"}]},"sessionId":"s1"}""",
        )
        check(settings.first == 200, "decide status")
        check(settings.second.contains("\"kind\":\"ui.launch\""), "decide action kind")
        check(settings.second.contains("com.huawei.hmos.settings"), "decide bundle")
        check(settings.second.contains("\"sessionId\":\"s1\""), "decide session")

        val alias = post("""{"goal":"闹钟"}""")
        check(alias.first == 200 && alias.second.contains("com.huawei.hmos.clock"), "alias match")

        val ambiguous = post("""{"goal":"notes"}""")
        check(ambiguous.first == 200, "ambiguous status")
        check(ambiguous.second.contains("\"needUser\":true"), "ambiguous needs user")
        check(ambiguous.second.contains("\"options\""), "ambiguous options")

        val payment = post("""{"goal":"pay now"}""")
        check(payment.first == 200, "payment status")
        check(payment.second.contains("Payment"), "payment handover")

        val unknown = post("""{"goal":"zzz"}""")
        check(unknown.first == 200 && unknown.second.contains("\"needUser\":true"), "unknown")

        post("""{"goal":"settings","sessionId":"s2"}""")
        post("""{"goal":"clock","sessionId":"s2"}""")
        val session = get("/session/s2")
        check(session.first == 200, "session status")
        val decisions = JsonParser.parseString(session.second).asJsonObject
            .getAsJsonArray("decisions")
        check(decisions.size() == 2, "session has two decisions")

        val invalid = post("{")
        check(invalid.first == 400, "invalid JSON is rejected")

        val wrongMethod = get("/decide")
        check(wrongMethod.first == 405, "GET /decide is rejected")
    } finally {
        server.stop()
    }

    println("ServerTest: $passed assertions passed")
}
