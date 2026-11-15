package com.hopa.backend.tasks

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.gateway.DeviceRegistry
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

class TaskRoutingTest {
    private val identities = listOf(
        DeviceIdentity("dev-phone", "hh-1", "mem-1"),
        DeviceIdentity("dev-pc", "hh-1", "mem-1"),
        DeviceIdentity("dev-other", "hh-2", "mem-2"),
    )

    private fun config() = com.hopa.backend.ServerConfig(
        version = "0.1.0",
        auth = MapAuth(identities.associate { "tok-${it.deviceId}" to it }),
        devices = MapDirectory(identities.associateBy { it.deviceId }),
    )

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

    private fun create(to: String, id: String = UUID.randomUUID().toString()) = Envelope(
        v = 1,
        id = id,
        type = "task.create",
        ts = 1,
        to = to,
        body = buildJsonObject { put("goal", "open the settings app") },
    )

    @Test
    fun `a task is delivered to the target and acked to the sender`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice("dev-phone", "tok-dev-phone")
        val pc = FakeDevice("dev-pc", "tok-dev-pc")
        phone.connect(http)
        phone.send(hello("dev-phone"))
        phone.expect("device.hello.ack")
        pc.connect(http)
        pc.send(hello("dev-pc"))
        pc.expect("device.hello.ack")
        phone.expect("presence")

        val message = create("dev-pc")
        phone.send(message)

        val ack = phone.expect("task.ack")
        assertEquals("delivered", ack.bodyString("state"))
        assertEquals("false", ack.bodyString("duplicate"))

        val delivered = pc.expect("task.create")
        assertEquals(message.id, delivered.id)
        assertEquals(ack.bodyString("task"), delivered.task)
        assertEquals(message.body, delivered.body)
        assertEquals("dev-phone", delivered.from)
    }

    @Test
    fun `the same message id sent three times creates one task and one delivery`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice("dev-phone", "tok-dev-phone")
        val pc = FakeDevice("dev-pc", "tok-dev-pc")
        phone.connect(http)
        phone.send(hello("dev-phone"))
        phone.expect("device.hello.ack")
        pc.connect(http)
        pc.send(hello("dev-pc"))
        pc.expect("device.hello.ack")
        phone.expect("presence")

        val message = create("dev-pc")
        phone.send(message)
        val first = phone.expect("task.ack")
        val taskId = first.bodyString("task")
        pc.expect("task.create")

        phone.send(message)
        val second = phone.expect("task.ack")
        phone.send(message)
        val third = phone.expect("task.ack")

        assertEquals(taskId, second.bodyString("task"))
        assertEquals(taskId, third.bodyString("task"))
        assertEquals("true", second.bodyString("duplicate"))
        pc.expectNothing("task.create")
    }

    @Test
    fun `a target in another household is refused and never delivered`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice("dev-phone", "tok-dev-phone")
        val other = FakeDevice("dev-other", "tok-dev-other")
        phone.connect(http)
        phone.send(hello("dev-phone"))
        phone.expect("device.hello.ack")
        other.connect(http)
        other.send(hello("dev-other"))
        other.expect("device.hello.ack")

        phone.send(create("dev-other"))

        assertEquals("E_TENANT", phone.expect("error").bodyString("code"))
        other.expectNothing("task.create")
    }

    @Test
    fun `a task for an offline device is queued and delivered on hello`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice("dev-phone", "tok-dev-phone")
        val pc = FakeDevice("dev-pc", "tok-dev-pc")
        phone.connect(http)
        phone.send(hello("dev-phone"))
        phone.expect("device.hello.ack")

        phone.send(create("dev-pc"))
        val ack = phone.expect("task.ack")
        assertEquals("queued", ack.bodyString("state"))
        val taskId = ack.bodyString("task")

        pc.connect(http)
        pc.send(hello("dev-pc"))
        pc.expect("device.hello.ack")
        val delivered = pc.expect("task.create")
        assertEquals(taskId, delivered.task)
    }

    @Test
    fun `a task is redelivered until the target acks it`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice("dev-phone", "tok-dev-phone")
        val pc = FakeDevice("dev-pc", "tok-dev-pc")
        phone.connect(http)
        phone.send(hello("dev-phone"))
        phone.expect("device.hello.ack")
        pc.connect(http)
        pc.send(hello("dev-pc"))
        pc.expect("device.hello.ack")
        phone.expect("presence")

        phone.send(create("dev-pc"))
        val taskId = phone.expect("task.ack").bodyString("task")
        assertEquals(taskId, pc.expect("task.create").task)

        // The PC drops before it can ack: the task must not be lost.
        pc.close()
        val again = FakeDevice("dev-pc", "tok-dev-pc")
        again.connect(http)
        again.send(hello("dev-pc"))
        again.expect("device.hello.ack")
        assertEquals(taskId, again.expect("task.create").task)

        again.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.ack",
                ts = 2,
                to = "dev-phone",
                task = taskId,
                body = buildJsonObject { put("state", "delivered") },
            ),
        )
        // Wait for the relay: the ack must be processed before the socket closes.
        assertEquals(taskId, phone.expect("task.ack").task)
        again.close()

        val third = FakeDevice("dev-pc", "tok-dev-pc")
        third.connect(http)
        third.send(hello("dev-pc"))
        third.expect("device.hello.ack")
        third.expectNothing("task.create")
    }

    @Test
    fun `a replayed task does not get a second queued copy`() = testApplication {
        application { module(config()) }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice("dev-phone", "tok-dev-phone")
        val pc = FakeDevice("dev-pc", "tok-dev-pc")
        phone.connect(http)
        phone.send(hello("dev-phone"))
        phone.expect("device.hello.ack")

        val message = create("dev-pc")
        phone.send(message)
        phone.send(message)
        val first = phone.expect("task.ack")
        val second = phone.expect("task.ack")
        assertEquals("true", second.bodyString("duplicate"))
        assertEquals(first.bodyString("task"), second.bodyString("task"))

        pc.connect(http)
        pc.send(hello("dev-pc"))
        pc.expect("device.hello.ack")
        pc.expect("task.create")
        pc.expectNothing("task.create")
    }
}
