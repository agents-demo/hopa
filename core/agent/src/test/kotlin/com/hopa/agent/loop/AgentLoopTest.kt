package com.hopa.agent.loop

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.action.ApprovalPolicy
import com.hopa.agent.decision.DecisionRuntime
import com.hopa.agent.decision.command.CommandDecisionPolicy
import com.hopa.agent.decision.model.ModelDecisionPolicy
import com.hopa.agent.decision.model.ModelStepPolicy
import com.hopa.catalog.testing.TestCatalog
import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.ports.InstalledApp
import com.hopa.contracts.testing.FakeApproval
import com.hopa.contracts.testing.FakeClock
import com.hopa.contracts.testing.FakeDevice
import com.hopa.contracts.turn.TurnContext
import com.hopa.decision.ActionClass
import com.hopa.decision.ConformanceStatus
import com.hopa.decision.classifier.IntentClassifier
import com.hopa.decision.DecisionContext
import com.hopa.decision.DecisionCoordinator
import com.hopa.decision.DecisionLayer
import com.hopa.decision.DecisionMode
import com.hopa.decision.DecisionRegistry
import com.hopa.decision.DecisionRun
import com.hopa.decision.LatencyClass
import com.hopa.decision.LayerDecision
import com.hopa.decision.LayerMetadata
import com.hopa.decision.LayerStatus
import com.hopa.decision.Verb
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.runlog.store.InMemoryRunRecorder
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AgentLoopTest {
    @Test
    fun a_failed_command_does_not_keep_its_success_sentence() {
        val device = FakeDevice().apply { launchError = IllegalStateException("no window") }
        val clock = FakeClock()
        val recorder = InMemoryRunRecorder()
        val loop = AgentLoop(
            policy = CommandDecisionPolicy(IntentClassifier()),
            device = device,
            executor = ActionExecutor(
                device = device,
                browser = null,
                system = null,
                sandbox = null,
                policy = { ApprovalPolicy() },
                approval = FakeApproval(),
                recorder = recorder,
                factory = RunRecordFactory(clock),
                clock = clock,
            ),
            recorder = recorder,
            clock = clock,
            knowledge = TestCatalog.value,
        )

        val result = runBlocking {
            loop.run(
                "run-c",
                "trace-c",
                TurnContext(
                    goal = "open calculator",
                    installedApps = listOf(InstalledApp("calc.exe", "Calculator")),
                ),
            ) { false }
        }

        assertFalse(result.records.single().executed)
        assertTrue(result.answer.startsWith("I did not run that."), result.answer)
        assertEquals(ErrorCodes.DEVICE, result.error?.code)
    }

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

    @Test
    fun a_shadow_vote_is_recorded_and_changes_nothing() {
        val votes = mutableListOf<DecisionRun>()
        val asking = object : DecisionLayer {
            override val metadata = LayerMetadata(
                id = "asking",
                version = "1.0.0",
                latency = LatencyClass.MICRO,
                decidesUpTo = ActionClass.DANGEROUS,
                status = LayerStatus.DEFAULT,
                conformance = ConformanceStatus.PASSED,
                author = "test",
                summary = "asks about everything",
            )

            override suspend fun decide(context: DecisionContext): LayerDecision =
                LayerDecision(Verb.ASK, "always_ask", 0.9, "asking about everything")
        }
        val decisions = DecisionRuntime(
            coordinator = DecisionCoordinator(DecisionRegistry(listOf(asking))),
            mode = { DecisionMode.Automatic },
            shadow = { true },
            sink = { _, run -> votes += run },
        )
        val harness = Harness(replies = listOf(TAP, "Done."), decisions = decisions)
        val result = runBlocking {
            harness.loop.run("run-8", "trace-8", TurnContext("open settings")) { false }
        }

        // The layer said ASK; the model path still tapped, because D3 applies nothing.
        assertEquals(1, harness.device.taps)
        assertEquals(1, result.records.size)
        assertEquals(1, votes.size)
        assertEquals(Verb.ASK, votes.single().applied?.verb)
        assertEquals("always_ask", votes.single().applied?.reason)
    }

    @Test
    fun a_decision_layer_can_ask_instead_of_acting() {
        val harness = Harness(
            replies = listOf(OBSERVE, "Done."),
            decisions = decisionRuntime(Verb.ASK),
        )
        val result = runBlocking {
            harness.loop.run("run-9", "trace-9", TurnContext("look")) { false }
        }

        assertTrue(result.answer.contains("go-ahead"), result.answer)
        assertTrue(result.records.isEmpty())
        assertEquals(1, harness.model.calls)
    }

    @Test
    fun a_waiting_layer_stops_the_step() {
        val harness = Harness(
            replies = listOf(OBSERVE, "Done."),
            decisions = decisionRuntime(Verb.WAIT),
        )
        val result = runBlocking {
            harness.loop.run("run-10", "trace-10", TurnContext("look")) { false }
        }

        assertTrue(result.answer.contains("waiting", ignoreCase = true), result.answer)
        assertEquals(1, harness.model.calls)
    }

    @Test
    fun a_verify_vote_re_reads_and_skips_the_tap() {
        val harness = Harness(
            replies = listOf(TAP, "Done."),
            decisions = decisionRuntime(Verb.VERIFY),
        )
        val result = runBlocking {
            harness.loop.run("run-11", "trace-11", TurnContext("tap")) { false }
        }

        assertEquals(0, harness.device.taps)
        assertEquals("Done.", result.answer)
        assertEquals(2, harness.model.calls)
    }

    private fun decisionRuntime(verb: Verb): DecisionRuntime {
        val layer = object : DecisionLayer {
            override val metadata = LayerMetadata(
                id = "test-$verb".lowercase(),
                version = "1.0.0",
                latency = LatencyClass.MICRO,
                decidesUpTo = ActionClass.DANGEROUS,
                status = LayerStatus.DEFAULT,
                conformance = ConformanceStatus.PASSED,
                author = "test",
                summary = "a layer that answers $verb",
            )

            override suspend fun decide(context: DecisionContext): LayerDecision =
                LayerDecision(verb, "test_${verb.name.lowercase()}", 0.9, "test says $verb")
        }
        return DecisionRuntime(
            coordinator = DecisionCoordinator(DecisionRegistry(listOf(layer))),
            mode = { DecisionMode.Automatic },
            shadow = { false },
            applies = { true },
        )
    }

    @Test
    fun the_prompt_carries_the_packages_installed_on_this_phone() {
        val harness = Harness(replies = listOf("Done."))
        val installed = listOf(InstalledApp("tv.danmaku.bili", "Bilibili"))
        runBlocking {
            harness.loop.run(
                "run-7",
                "trace-7",
                TurnContext("open bilibili", installedApps = installed, platform = "android"),
            ) { false }
        }

        val prompt = harness.model.lastSystem
        assertTrue(prompt.contains("Bilibili: tv.danmaku.bili"))
        assertTrue(prompt.contains("posting, commenting and following are public actions: ask."))
        assertTrue(prompt.contains("\"app\":\"tv.danmaku.bili\""))
    }

    private class Harness(
        replies: List<String>,
        val device: FakeDevice = FakeDevice(),
        approval: FakeApproval = FakeApproval(),
        decisions: DecisionRuntime? = null,
    ) {
        val recorder = InMemoryRunRecorder()
        val model = ScriptedModel(replies)
        val clock = FakeClock()
        val loop = AgentLoop(
            policy = ModelDecisionPolicy(
                steps = ModelStepPolicy(model),
                knowledge = { TestCatalog.value },
            ),
            device = device,
            executor = ActionExecutor(
                device = device,
                browser = null,
                system = null,
                sandbox = null,
                policy = { ApprovalPolicy() },
                approval = approval,
                recorder = recorder,
                factory = RunRecordFactory(clock),
                clock = clock,
            ),
            recorder = recorder,
            clock = clock,
            knowledge = TestCatalog.value,
            decisions = decisions,
        )
    }

    private class ScriptedModel(private val replies: List<String>) : ModelPort {
        var calls = 0
        var usage = ModelUsage()
        var lastSystem = ""

        override suspend fun complete(request: ModelRequest): ModelReply {
            lastSystem = request.messages.firstOrNull { it.role == "system" }?.content ?: lastSystem
            val text = replies.getOrElse(calls) { replies.lastOrNull().orEmpty() }
            calls += 1
            return ModelReply(text = text, usage = usage)
        }
    }

    private companion object {
        const val TAP = """{"schemaVersion":"1","kind":"ui.tap","ref":"e1","timeoutMs":3000}"""
        const val PAY = """{"schemaVersion":"1","kind":"payment.checkout","ref":"e9","timeoutMs":3000}"""
        const val OBSERVE = """{"schemaVersion":"1","kind":"ui.observe","timeoutMs":3000}"""
        const val LAUNCH =
            """{"schemaVersion":"1","kind":"ui.launch","app":"com.example.app","timeoutMs":3000}"""
    }
}
