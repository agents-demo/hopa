package com.hopa.sidecar.browser

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** The browser port is one request line and one reply for each `web.*` call. */
class HostBrowserTest {
    @Test
    fun navigate_sends_a_browser_request_and_returns_the_host_text() = runBlocking {
        val sent = CompletableDeferred<JsonObject>()
        val browser = HostBrowser({ sent.complete(it) }, timeoutMillis = 5_000)

        val call = async { browser.navigate("https://example.com") }
        val request = sent.await()
        assertEquals("browser.request", request.text("type"))
        assertEquals("navigate", request.text("op"))
        assertEquals("https://example.com", request.text("url"))

        browser.resolve(
            request.text("id"),
            buildJsonObject {
                put("ok", true)
                put("text", "navigated to https://example.com")
            },
        )
        assertEquals("navigated to https://example.com", call.await())
    }

    @Test
    fun a_refused_action_is_an_error_not_an_empty_read() = runBlocking {
        val sent = CompletableDeferred<JsonObject>()
        val browser = HostBrowser({ sent.complete(it) }, timeoutMillis = 5_000)

        val call = async { runCatching { browser.read() }.exceptionOrNull() }
        val request = sent.await()
        browser.resolve(
            request.text("id"),
            buildJsonObject {
                put("ok", false)
                put("error", "the Edge WebView2 runtime is not available")
            },
        )
        val error = call.await()
        assertTrue(error is IllegalStateException)
        assertEquals("the Edge WebView2 runtime is not available", error?.message)
    }

    @Test
    fun protocol_request_carries_the_action_fields() {
        val request = Protocol.browserRequest("b-1", "type") {
            put("text", "Michael")
            put("ref", "w3")
        }
        assertEquals("browser.request", request.text("type"))
        assertEquals("b-1", request.text("id"))
        assertEquals("type", request.text("op"))
        assertEquals("Michael", request.text("text"))
        assertEquals("w3", request.text("ref"))
    }
}
