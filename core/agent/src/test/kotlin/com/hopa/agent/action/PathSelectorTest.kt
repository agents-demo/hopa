package com.hopa.agent.action

import com.hopa.contracts.ports.SystemPort
import com.hopa.contracts.testing.FakeApproval
import com.hopa.contracts.testing.FakeClock
import com.hopa.contracts.testing.FakeDevice
import com.hopa.contracts.turn.ExecutionResult
import com.hopa.contracts.wire.Action
import com.hopa.runlog.record.RunChain
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.runlog.store.InMemoryRunRecorder
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The selector runs before the gate: it may replace a UI launch with a URI, and
 * the record must describe the path that actually ran, not the one proposed.
 */
class PathSelectorTest {
    @Test
    fun an_intent_replaces_a_launch_and_is_recorded() = runBlocking {
        val harness = Harness(IntentSelector())
        val result = harness.execute(Action(kind = "ui.launch", app = "wifi"))

        assertEquals("system.openLink", result.record.action.kind)
        assertEquals("ms-settings:network-wifi", result.record.action.url)
        assertEquals("intent", result.record.tier)
        assertEquals(listOf("ms-settings:network-wifi"), harness.system.opened)
        assertTrue(RunChain.verify(listOf(result.record)))
    }

    @Test
    fun a_tier_is_recorded_even_when_the_action_is_unchanged() = runBlocking {
        val harness = Harness(IntentSelector())
        val result = harness.execute(Action(kind = "ui.tap", ref = "e1"))

        assertEquals("ui.tap", result.record.action.kind)
        assertEquals("uia", result.record.tier)
        assertEquals(1, harness.device.taps)
    }

    @Test
    fun without_a_selector_the_tier_stays_empty() = runBlocking {
        val harness = Harness(selector = null)
        val result = harness.execute(Action(kind = "ui.tap", ref = "e1"))

        assertEquals("ui.tap", result.record.action.kind)
        assertEquals("", result.record.tier)
    }

    private class IntentSelector : PathSelector {
        override fun choose(action: Action): PlannedAction =
            if (action.kind == "ui.launch" && action.app == "wifi") {
                PlannedAction(
                    action.copy(kind = "system.openLink", url = "ms-settings:network-wifi", app = null),
                    PathTier.INTENT,
                )
            } else {
                PlannedAction(action, PathTier.UIA)
            }
    }

    private class Harness(selector: PathSelector?) {
        private val approval = FakeApproval(allow = true)
        private val clock = FakeClock()
        private val recorder = InMemoryRunRecorder()
        val device = FakeDevice()
        val system = RecordingSystem()
        private val executor = ActionExecutor(
            device = device,
            browser = null,
            system = system,
            sandbox = null,
            policy = { ApprovalPolicy() },
            approval = approval,
            recorder = recorder,
            factory = RunRecordFactory(clock),
            clock = clock,
            selector = selector,
        )

        suspend fun execute(action: Action): ExecutionResult = executor.execute(
            runId = "run-test",
            step = 0,
            traceId = "trace-test",
            action = action,
            before = device.observation,
        )
    }

    private class RecordingSystem : SystemPort {
        val opened = mutableListOf<String>()

        override suspend fun openLink(url: String) {
            opened += url
        }

        override suspend fun setAlarm(hour: Int, minute: Int, label: String) = Unit

        override suspend fun addEvent(title: String, startMillis: Long, endMillis: Long) = Unit

        override suspend fun share(text: String) = Unit

        override suspend fun sendMessage(target: String, text: String) = Unit

        override suspend fun call(number: String) = Unit

        override suspend fun delete(query: String) = Unit

        override suspend fun uninstall(packageName: String) = Unit
    }
}
