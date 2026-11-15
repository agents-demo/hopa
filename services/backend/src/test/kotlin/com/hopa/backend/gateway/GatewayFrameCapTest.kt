package com.hopa.backend.gateway

import com.hopa.backend.ServerConfig
import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.MapAuth
import com.hopa.backend.harness.MapDirectory
import com.hopa.backend.harness.bodyString
import com.hopa.backend.module
import com.hopa.backend.protocol.Envelope
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.server.testing.testApplication
import java.util.UUID
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Test

class GatewayFrameCapTest {
    private val identities = listOf(
        DeviceIdentity("dev-a", "hh-1", "mem-1"),
        DeviceIdentity("dev-b", "hh-1", "mem-1"),
    )

    private fun config() = ServerConfig(
        version = "0.1.0",
        auth = MapAuth(identities.associate { "tok-${it.deviceId}" to it }),
        devices = MapDirectory(identities.associateBy { it.deviceId }),
    )

    @Test
    fun `a frame over the cap is answered with E_SCHEMA, not a dropped socket`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val device = FakeDevice("dev-a", "tok-dev-a")
        device.connect(http)
        device.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "device.hello",
                ts = 0,
                from = "dev-a",
                body = buildJsonObject { put("platform", "android") },
            ),
        )
        device.expect("device.hello.ack")

        device.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.create",
                ts = 0,
                to = "dev-b",
                body = buildJsonObject { put("blob", "a".repeat(66_000)) },
            ),
        )

        assertEquals("E_SCHEMA", device.expect("error").bodyString("code"))
    }
}
