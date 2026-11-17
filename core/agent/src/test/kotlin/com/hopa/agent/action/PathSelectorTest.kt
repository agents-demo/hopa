package com.hopa.agent.action

import com.hopa.contracts.ports.DevicePort
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
import org.junit.jupiter.api.Assertions.assertNull
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

    @Test
    fun an_unavailable_tier_falls_through_and_the_surviving_tier_is_recorded() = runBlocking {
        val harness = FallbackHarness(
            FallbackSelector(),
            FakeDevice(),
            FailingSystem(),
        )
        val result = harness.execute(Action(kind = "ui.launch", app = "wifi"))

        assertEquals("ui.launch", result.record.action.kind)
        assertEquals("uia", result.record.tier)
        assertTrue(result.record.executed)
        assertNull(result.record.error)
        assertEquals(
            listOf("tier intent unavailable (E_UNSUPPORTED); falling back to uia"),
            harness.fallbacks,
        )
        assertTrue(RunChain.verify(listOf(result.record)))
    }

    @Test
    fun when_every_tier_is_unavailable_the_last_tier_is_recorded() = runBlocking {
        val harness = FallbackHarness(
            FallbackSelector(),
            UnsupportedLaunchDevice(),
            FailingSystem(),
        )
        val result = harness.execute(Action(kind = "ui.launch", app = "wifi"))

        assertEquals("uia", result.record.tier)
        assertEquals(false, result.record.executed)
        assertEquals("E_UNSUPPORTED", result.record.error)
        assertEquals(1, harness.fallbacks.size)
        assertTrue(RunChain.verify(listOf(result.record)))
    }

    @Test
    fun a_device_error_is_not_retried_as_a_fallback() = runBlocking {
        val harness = FallbackHarness(
            SingleTierSelector(),
            BrokenLaunchDevice(),
            RecordingSystem(),
        )
        val result = harness.execute(Action(kind = "ui.launch", app = "wifi"))

        assertEquals("E_DEVICE", result.record.error)
        assertEquals("uia", result.record.tier)
        assertTrue(harness.fallbacks.isEmpty())
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

    private class SingleTierSelector : PathSelector {
        override fun choose(action: Action): PlannedAction = PlannedAction(action, PathTier.UIA)
    }

    /** Two paths for one action, so an unavailable intent can reach the UIA launch. */
    private class FallbackSelector : PathSelector {
        override fun choose(action: Action): PlannedAction = plan(action).first()

        override fun plan(action: Action): List<PlannedAction> = listOf(
            PlannedAction(
                action.copy(kind = "system.openLink", url = "ms-settings:network-wifi", app = null),
                PathTier.INTENT,
            ),
            PlannedAction(action, PathTier.UIA),
        )
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

    private class FallbackHarness(
        selector: PathSelector,
        device: DevicePort,
        system: SystemPort,
    ) {
        val fallbacks = mutableListOf<String>()
        private val clock = FakeClock()
        private val executor = ActionExecutor(
            device = device,
            browser = null,
            system = system,
            sandbox = null,
            policy = { ApprovalPolicy() },
            approval = FakeApproval(allow = true),
            recorder = InMemoryRunRecorder(),
            factory = RunRecordFactory(clock),
            clock = clock,
            selector = selector,
            onFallback = { fallbacks += it },
        )

        suspend fun execute(action: Action): ExecutionResult = executor.execute(
            runId = "run-fallback",
            step = 0,
            traceId = "trace-fallback",
            action = action,
            before = FakeDevice.sample(),
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

    private class FailingSystem : SystemPort {
        override suspend fun openLink(url: String) =
            throw UnsupportedOperationException("no system port")

        override suspend fun setAlarm(hour: Int, minute: Int, label: String) = Unit

        override suspend fun addEvent(title: String, startMillis: Long, endMillis: Long) = Unit

        override suspend fun share(text: String) = Unit

        override suspend fun sendMessage(target: String, text: String) = Unit

        override suspend fun call(number: String) = Unit

        override suspend fun delete(query: String) = Unit

        override suspend fun uninstall(packageName: String) = Unit
    }

    private class UnsupportedLaunchDevice : DevicePort by FakeDevice() {
        override suspend fun launch(packageName: String) =
            throw UnsupportedOperationException("no launcher")
    }

    private class BrokenLaunchDevice : DevicePort by FakeDevice() {
        override suspend fun launch(packageName: String) =
            throw IllegalStateException("launcher exploded")
    }
}
