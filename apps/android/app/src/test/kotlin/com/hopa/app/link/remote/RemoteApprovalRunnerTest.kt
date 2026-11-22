package com.hopa.app.link.remote

import com.hopa.backend.link.BackendLink
import com.hopa.backend.link.BackendState
import com.hopa.backend.wire.BackendEnvelope
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.json.HopaJson
import com.hopa.contracts.wire.Action
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RemoteApprovalRunnerTest {
    @Test
    fun `an approval request is acked and the answer is a task result`() = runBlocking {
        val link = RecordingLink()
        val approval = RecordingApproval(allow = true)
        val runner = RemoteApprovalRunner(
            deviceId = { "dev-phone" },
            link = { link },
            approval = approval,
            foreground = { true },
            postApproval = {},
            timeoutMillis = 2_000,
        )

        runner.handle(task())

        assertEquals(1, approval.asked)
        assertEquals("task.ack", link.frames.first().type)
        val result = link.frames.last()
        assertEquals("task.result", result.type)
        assertEquals("dev-pc", result.to)
        assertEquals("t-1", result.task)
        assertTrue(result.body["approval"]!!.jsonObject["allow"]!!.jsonPrimitive.boolean)
    }

    @Test
    fun `a refusal is sent as a result with allow false`() = runBlocking {
        val link = RecordingLink()
        val runner = RemoteApprovalRunner(
            deviceId = { "dev-phone" },
            link = { link },
            approval = RecordingApproval(allow = false),
            foreground = { true },
            postApproval = {},
            timeoutMillis = 2_000,
        )

        runner.handle(task())

        val result = link.frames.last()
        assertEquals("task.result", result.type)
        assertEquals(false, result.body["approval"]!!.jsonObject["allow"]!!.jsonPrimitive.boolean)
    }

    private fun task(): BackendEnvelope {
        val request = ApprovalRequest(
            title = "Confirm payment",
            body = "Money may leave your account.",
            amount = "12.40",
            merchant = "Example Shop",
            consequence = "HOPA cannot undo a payment.",
            isPayment = true,
            action = Action(kind = "payment.pay", text = "12.40"),
        )
        return BackendEnvelope(
            id = "m-1",
            type = "task.needs_approval",
            ts = 1,
            from = "dev-pc",
            to = "dev-phone",
            task = "t-1",
            body = buildJsonObject {
                put("approval", HopaJson.element.encodeToJsonElement(ApprovalRequest.serializer(), request))
            },
        )
    }

    private class RecordingApproval(private val allow: Boolean) : ApprovalGateway {
        var asked = 0
        override suspend fun approve(request: ApprovalRequest): Boolean {
            asked += 1
            return allow
        }
    }

    private class RecordingLink : BackendLink {
        val frames = mutableListOf<BackendEnvelope>()
        override val state = MutableStateFlow<BackendState>(
            BackendState.Live(deviceId = "dev-phone", queued = 0, peers = listOf("dev-pc")),
        )
        override var onTask: (suspend (BackendEnvelope) -> Unit)? = null
        override var onApproval: (suspend (BackendEnvelope) -> Unit)? = null

        override fun start(scope: CoroutineScope) = Unit
        override suspend fun stop() = Unit
        override suspend fun send(frame: BackendEnvelope) {
            frames += frame
        }

        override suspend fun ack(task: BackendEnvelope) {
            frames += task.copy(id = "ack-${task.task}", type = "task.ack")
        }

        override suspend fun ping() = Unit
    }
}
