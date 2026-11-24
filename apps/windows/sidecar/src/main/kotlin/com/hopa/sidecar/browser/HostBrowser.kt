package com.hopa.sidecar.browser

import com.hopa.contracts.ports.BrowserPort
import com.hopa.sidecar.protocol.Protocol
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * The browser target. Every `web.*` action travels to the .NET host, which
 * owns the WebView2 window; the engine only sees text and refs.
 *
 * A missing runtime is an error from the host, never a silent success: the
 * model must be able to tell the person that the page was not read.
 */
class HostBrowser(
    private val send: (JsonObject) -> Unit,
    private val timeoutMillis: Long = 30_000,
) : BrowserPort {
    private val pending = ConcurrentHashMap<String, CompletableDeferred<JsonObject>>()
    private val counter = AtomicInteger(0)

    fun resolve(id: String, result: JsonObject) {
        pending.remove(id)?.complete(result)
    }

    override suspend fun navigate(url: String): String =
        request("navigate") { put("url", url) }

    override suspend fun read(): String = request("read") {}

    override suspend fun click(ref: String) {
        request("click") { put("ref", ref) }
    }

    override suspend fun type(text: String, ref: String?) {
        request("type") {
            put("text", text)
            ref?.let { put("ref", it) }
        }
    }

    private suspend fun request(op: String, fields: JsonObjectBuilder.() -> Unit): String {
        val id = "browser-${counter.incrementAndGet()}"
        val deferred = CompletableDeferred<JsonObject>()
        pending[id] = deferred
        try {
            send(Protocol.browserRequest(id, op, fields))
            val result = withTimeout(timeoutMillis) { deferred.await() }
            val ok = result["ok"]?.jsonPrimitive?.booleanOrNull == true
            if (!ok) {
                throw IllegalStateException(
                    result["error"]?.jsonPrimitive?.contentOrNull ?: "the host refused $op",
                )
            }
            return result["text"]?.jsonPrimitive?.contentOrNull.orEmpty()
        } finally {
            pending.remove(id)
        }
    }
}
