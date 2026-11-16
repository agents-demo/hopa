package com.hopa.backend.tasks

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.gateway.DeviceRegistry
import com.hopa.backend.harness.MapDirectory
import com.hopa.backend.protocol.Envelope
import java.util.UUID
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Test

class TaskDeadlineTest {
    private val now = 1_800_000_000_000L
    private val phone = DeviceIdentity("dev-phone", "hh-1", "mem-1")
    private val pc = DeviceIdentity("dev-pc", "hh-1", "mem-1")
    private val devices = MapDirectory(listOf(phone, pc).associateBy { it.deviceId })
    private val tenMinutes = 10 * 60 * 1000L

    private fun router() = TaskRouter(InMemoryTaskStore(), DeviceRegistry(), devices, now = { now })

    private fun create(deadlineAt: Long?) = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "task.create",
        ts = now,
        to = "dev-pc",
        body = buildJsonObject {
            put("goal", "open the settings app")
            if (deadlineAt != null) put("deadlineAt", deadlineAt)
        },
    )

    private fun deadlineOf(deadlineAt: Long?): Long =
        (router().route(phone, create(deadlineAt)) as RouteResult.Accepted).task.deadlineAt

    @Test
    fun `a body deadline is honoured`() {
        assertEquals(now + 30 * 60 * 1000, deadlineOf(now + 30 * 60 * 1000))
    }

    @Test
    fun `no body deadline means ten minutes`() {
        assertEquals(now + tenMinutes, deadlineOf(null))
    }

    @Test
    fun `a deadline in the past falls back to ten minutes`() {
        assertEquals(now + tenMinutes, deadlineOf(now - 1_000))
    }

    @Test
    fun `a deadline beyond a day falls back to ten minutes`() {
        assertEquals(now + tenMinutes, deadlineOf(now + 25 * 60 * 60 * 1000))
    }
}
