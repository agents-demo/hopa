package com.hopa.backend.gateway

import com.hopa.backend.ServerConfig
import com.hopa.backend.auth.AuthPort
import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.MapAuth
import com.hopa.backend.harness.bodyString
import com.hopa.backend.module
import com.hopa.backend.protocol.Envelope
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.server.testing.testApplication
import java.util.UUID
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Test

class GatewayHandshakeTest {
    private fun config(auth: AuthPort) = ServerConfig(version = "0.1.0", auth = auth)

    private fun hello(deviceId: String) = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "device.hello",
        ts = 0,
        from = deviceId,
        body = buildJsonObject {
            put("platform", "android")
            put("name", "Pixel 9")
            put("appVersion", "0.1.0")
        },
    )

    private fun Envelope.peers(): Set<String> =
        body["peers"]!!.jsonArray.map { it.jsonPrimitive.content }.toSet()

    private fun auth() = MapAuth(
        mapOf(
            "tok-a" to DeviceIdentity("dev-a", "hh-1", "mem-1"),
            "tok-b" to DeviceIdentity("dev-b", "hh-1", "mem-1"),
            "tok-c" to DeviceIdentity("dev-c", "hh-2", "mem-2"),
        ),
    )

    @Test
    fun `a second device joins, sees the roster and is announced to the first`() = testApplication {
        application { module(config(auth())) }
        val http = createClient { install(WebSockets) }
        val a = FakeDevice("dev-a", "tok-a")
        val b = FakeDevice("dev-b", "tok-b")
        val c = FakeDevice("dev-c", "tok-c")

        a.connect(http)
        a.send(hello("dev-a"))
        val ackA = a.expect("device.hello.ack")
        assertEquals("dev-a", ackA.to)
        assertEquals("25", ackA.bodyString("heartbeatSec"))
        assertEquals(setOf("dev-a"), ackA.peers())

        b.connect(http)
        b.send(hello("dev-b"))
        val ackB = b.expect("device.hello.ack")
        assertEquals(setOf("dev-a", "dev-b"), ackB.peers())

        val announced = a.expect("presence")
        assertEquals("dev-b", announced.bodyString("device"))
        assertEquals(setOf("dev-a", "dev-b"), announced.peers())

        c.connect(http)
        c.send(hello("dev-c"))
        assertEquals(setOf("dev-c"), c.expect("device.hello.ack").peers())
        c.expectNothing("presence")
    }

    @Test
    fun `an unknown token is answered with E_AUTH and the socket closes`() = testApplication {
        application { module(config(auth())) }
        val http = createClient { install(WebSockets) }
        val unknown = FakeDevice("dev-x", "nope")

        unknown.connect(http)

        assertEquals("E_AUTH", unknown.expect("error").bodyString("code"))
    }

    @Test
    fun `leaving the household announces the device offline`() = testApplication {
        application { module(config(auth())) }
        val http = createClient { install(WebSockets) }
        val a = FakeDevice("dev-a", "tok-a")
        val b = FakeDevice("dev-b", "tok-b")
        a.connect(http)
        a.send(hello("dev-a"))
        a.expect("device.hello.ack")
        b.connect(http)
        b.send(hello("dev-b"))
        b.expect("device.hello.ack")
        a.expect("presence")

        b.close()

        val offline = a.expect("presence")
        assertEquals("dev-b", offline.bodyString("device"))
        assertEquals("false", offline.body["online"]!!.jsonPrimitive.content)
        assertEquals(setOf("dev-a"), offline.peers())
    }

    @Test
    fun `a replaced socket does not announce the device offline`() = testApplication {
        application { module(config(auth())) }
        val http = createClient { install(WebSockets) }
        val a = FakeDevice("dev-a", "tok-a")
        val b = FakeDevice("dev-b", "tok-b")
        a.connect(http)
        a.send(hello("dev-a"))
        a.expect("device.hello.ack")
        b.connect(http)
        b.send(hello("dev-b"))
        b.expect("device.hello.ack")
        a.expect("presence")

        // The device reconnects before the old socket has finished closing.
        val again = FakeDevice("dev-a", "tok-a")
        again.connect(http)
        again.send(hello("dev-a"))
        again.expect("device.hello.ack")
        b.expect("presence")

        a.close()

        // The device is still online on the new socket, so peers must not hear
        // that it went away.
        b.expectNothing("presence")
        again.send(ping())
        again.expect("pong")
    }

    private fun ping() = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "ping",
        ts = 0,
    )
}
