package com.hopa.core.loop

import com.hopa.core.gate.ActionExecutor
import com.hopa.core.gate.ApprovalPolicy
import com.hopa.core.model.ModelPort
import com.hopa.core.model.ModelReply
import com.hopa.core.model.ModelRequest
import com.hopa.core.model.ModelUsage
import com.hopa.core.records.InMemoryRunRecorder
import com.hopa.core.records.RunRecordFactory
import com.hopa.core.testing.FakeApproval
import com.hopa.core.testing.FakeClock
import com.hopa.core.testing.FakeDevice
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentLoopTest {
    @Test
    fun a_read_action_runs_then_the_loop_answers() {
        val harness = Harness(replies = listOf(TAP, "All done."))
        val result = runBlocking {
            harness.loop.run("run-1", "trace-1", TurnContext("open settings")) { false }
        }

        assertEquals("All done.", result.answer)
        assertEquals(1, result.records.size)
        assertTrue(result.records.single().executed)
        assertEquals(1_500L, harness.clock.slept)
    }

    @Test
    fun a_payment_is_refused_with_an_honest_record() {
        val approval = FakeApproval(allow = false)
        val harness = Harness(replies = listOf(PAY, "Stopped."), approval = approval)
        val result = runBlocking {
            harness.loop.run("run-2", "trace-2", TurnContext("pay")) { false }
        }

        assertEquals(1, approval.asked)
        val record = result.records.single()
        assertFalse(record.executed)
        assertEquals(false, record.approved)
        assertEquals("payment", record.classification)
    }

    @Test
    fun fourteen_steps_then_a_final_text_call() {
        val replies = List(15) { index -> if (index < 14) OBSERVE else "Summary." }
        val harness = Harness(replies = replies)
        val result = runBlocking {
            harness.loop.run("run-3", "trace-3", TurnContext("look")) { false }
        }

        assertEquals("Summary.", result.answer)
        assertEquals(15, harness.model.calls)
        assertEquals(14, result.records.size)
    }

    @Test
    fun a_duplicate_launch_is_skipped() {
        val harness = Harness(replies = listOf(LAUNCH, LAUNCH, "Done."))
        val result = runBlocking {
            harness.loop.run("run-4", "trace-4", TurnContext("open bilibili")) { false }
        }

        assertEquals(1, harness.device.launches)
        assertEquals(1, result.records.size)
        assertEquals("Done.", result.answer)
    }

    @Test
    fun cancel_stops_before_the_next_action() {
        val device = FakeDevice()
        val harness = Harness(replies = listOf(TAP, TAP), device = device)
        val result = runBlocking {
            harness.loop.run("run-5", "trace-5", TurnContext("tap")) { device.taps >= 1 }
        }

        assertEquals("Stopped.", result.answer)
        assertEquals(1, result.records.size)
        assertEquals(1, harness.model.calls)
    }

    @Test
    fun token_usage_is_summed_over_every_call() {
        val harness = Harness(replies = listOf(OBSERVE, OBSERVE, "Done."))
        harness.model.usage = ModelUsage(promptTokens = 1, completionTokens = 2, totalTokens = 3)
        val result = runBlocking {
            harness.loop.run("run-6", "trace-6", TurnContext("look")) { false }
        }

        assertEquals(9, result.usage.totalTokens)
        assertEquals(3, result.usage.promptTokens)
        assertEquals(6, result.usage.completionTokens)
    }

    private class Harness(
        replies: List<String>,
        val device: FakeDevice = FakeDevice(),
        approval: FakeApproval = FakeApproval(),
    ) {
        val recorder = InMemoryRunRecorder()
        val model = ScriptedModel(replies)
        val clock = FakeClock()
        val loop = AgentLoop(
            model = model,
            device = device,
            executor = ActionExecutor(
                device = device,
                browser = null,
                system = null,
                sandbox = null,
                policy = ApprovalPolicy(),
                approval = approval,
                recorder = recorder,
                factory = RunRecordFactory(clock),
                clock = clock,
            ),
            recorder = recorder,
            clock = clock,
        )
    }

    private class ScriptedModel(private val replies: List<String>) : ModelPort {
        var calls = 0
        var usage = ModelUsage()

        override suspend fun complete(request: ModelRequest): ModelReply {
            val text = replies.getOrElse(calls) { replies.lastOrNull().orEmpty() }
            calls += 1
            return ModelReply(text = text, usage = usage)
        }
    }

    private companion object {
        const val TAP = """{"schemaVersion":"1","kind":"ui.tap","ref":"e1","timeoutMs":3000}"""
        const val PAY = """{"schemaVersion":"1","kind":"payment.checkout","timeoutMs":3000}"""
        const val OBSERVE = """{"schemaVersion":"1","kind":"ui.observe","timeoutMs":3000}"""
        const val LAUNCH =
            """{"schemaVersion":"1","kind":"ui.launch","app":"com.example.app","timeoutMs":3000}"""
    }
}
