package com.hopa.core.gate

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.ErrorCodes
import com.hopa.core.records.InMemoryRunRecorder
import com.hopa.core.records.RunRecordFactory
import com.hopa.core.testing.FakeApproval
import com.hopa.core.testing.FakeClock
import com.hopa.core.testing.FakeDevice
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ActionExecutorTest {
    @Test
    fun a_denied_payment_is_recorded_as_refused() = runBlocking {
        val harness = Harness(allow = false)
        val result = harness.execute(Action(kind = "payment.checkout"))

        assertFalse(result.record.executed)
        assertEquals("payment", result.record.classification)
        assertEquals(false, result.record.approved)
        assertEquals(ErrorCodes.REFUSED, result.record.error)
        assertEquals(1, harness.approval.asked)
    }

    @Test
    fun a_missing_capability_is_recorded_as_unsupported() = runBlocking {
        val harness = Harness(allow = false)
        val result = harness.execute(Action(kind = "web.navigate", url = "https://example.com"))

        assertFalse(result.record.executed)
        assertEquals(ErrorCodes.UNSUPPORTED, result.record.error)
        assertEquals(0, harness.approval.asked)
    }

    @Test
    fun a_changed_screen_verifies_the_action() = runBlocking {
        val harness = Harness(allow = false, changingTap = true)
        val result = harness.execute(Action(kind = "ui.tap", ref = "e1"))

        assertTrue(result.record.executed)
        assertTrue(result.record.verified)
        assertNotEquals(result.record.beforeHash, result.record.afterHash)
    }

    @Test
    fun a_tap_that_changes_nothing_is_not_verified() = runBlocking {
        val harness = Harness(allow = false, changingTap = false)
        val result = harness.execute(Action(kind = "ui.tap", ref = "e1"))

        assertTrue(result.record.executed)
        assertFalse(result.record.verified)
    }

    @Test
    fun double_tap_and_long_press_use_their_own_gestures() = runBlocking {
        val harness = Harness(allow = false)
        harness.execute(Action(kind = "ui.doubleTap", ref = "e1"))
        harness.execute(Action(kind = "ui.longPress", ref = "e1"))

        assertEquals(1, harness.device.doubleTaps)
        assertEquals(1, harness.device.longPresses)
        assertEquals(0, harness.device.taps)
    }

    private class Harness(
        allow: Boolean,
        changingTap: Boolean = false,
    ) {
        val approval = FakeApproval(allow)
        private val clock = FakeClock()
        private val recorder = InMemoryRunRecorder()
        val device = FakeDevice(
            onTap = { tapped ->
                if (changingTap) {
                    tapped.observation = tapped.observation.copy(text = "changed")
                }
            },
        )
        private val executor = ActionExecutor(
            device = device,
            browser = null,
            system = null,
            sandbox = null,
            policy = ApprovalPolicy(),
            approval = approval,
            recorder = recorder,
            factory = RunRecordFactory(clock),
            clock = clock,
        )

        suspend fun execute(action: Action): ExecutionResult = executor.execute(
            runId = "run-test",
            step = 0,
            traceId = "trace-test",
            action = action,
            before = device.observation,
        )
    }
}
