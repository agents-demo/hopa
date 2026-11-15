package com.hopa.backend.harness

import com.hopa.backend.auth.AuthPort
import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.protocol.DecodeResult
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.protocol.GatewayCodec
import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.DefaultClientWebSocketSession
import io.ktor.client.plugins.websocket.webSocketSession
import io.ktor.client.request.header
import io.ktor.http.HttpHeaders
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonPrimitive

/**
 * A stand-in for the phone or the PC: a real WebSocket client speaking the real
 * wire format over a real socket. The client teams' code is not mocked — this
 * device is what their clients must be able to do.
 */
class FakeDevice(
    val deviceId: String,
    val token: String,
) {
    private lateinit var session: DefaultClientWebSocketSession

    suspend fun connect(client: HttpClient, path: String = "/v1/gateway") {
        session = client.webSocketSession(path) {
            header(HttpHeaders.Authorization, "Bearer $token")
        }
    }

    suspend fun send(envelope: Envelope) {
        session.send(Frame.Text(GatewayCodec.encode(envelope)))
    }

    /** The next frame of [type]; other frames are discarded. */
    suspend fun expect(type: String, timeoutMs: Long = 2_000): Envelope = withTimeout(timeoutMs) {
        while (true) {
            val frame = session.incoming.receive()
            if (frame !is Frame.Text) continue
            val decoded = GatewayCodec.decode(frame.readText())
            if (decoded is DecodeResult.Ok && decoded.envelope.type == type) {
                return@withTimeout decoded.envelope
            }
        }
        @Suppress("UNREACHABLE_CODE")
        error("the socket closed before a $type frame arrived")
    }

    /** Asserts that no frame of [type] arrives inside the window. */
    suspend fun expectNothing(type: String, withinMs: Long = 300) {
        try {
            expect(type, withinMs)
        } catch (_: Exception) {
            return
        }
        throw AssertionError("expected no $type frame, but one arrived")
    }

    suspend fun close() {
        session.close()
    }
}

/** The string value of a body field, or null when it is absent. */
fun Envelope.bodyString(key: String): String? =
    body[key]?.jsonPrimitive?.content

/** Token to identity, for tests only. Production resolves from Postgres. */
class MapAuth(private val byToken: Map<String, DeviceIdentity>) : AuthPort {
    override fun deviceFor(token: String): DeviceIdentity? = byToken[token]
}
