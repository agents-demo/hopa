package com.hopa.agent.action

import com.hopa.contracts.approval.ApprovalDecision
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.ports.SystemPort
import com.hopa.contracts.testing.FakeClock
import com.hopa.contracts.testing.FakeDevice
import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.ScreenSize
import com.hopa.runlog.record.RunChain
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.runlog.store.InMemoryRunRecorder
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** P4: the record names the device that answered the approval (ADR-0024). */
class ApprovalProvenanceTest {
    @Test
    fun a_phone_approval_is_named_on_the_record() = runBlocking {
        val harness = Harness(PhoneApproval())
        val result = harness.execute(Action(kind = "payment.pay", text = "100", ref = "pay-button"))

        assertTrue(result.record.executed)
        assertEquals(true, result.record.approved)
        assertEquals("phone", result.record.approver?.device)
        assertTrue(result.record.approver!!.at > 0)
        assertTrue(RunChain.verify(listOf(result.record)))
    }

    @Test
    fun a_pc_approval_is_named_on_the_record() = runBlocking {
        val harness = Harness(PcApproval())
        val result = harness.execute(Action(kind = "payment.pay", text = "100", ref = "pay-button"))

        assertTrue(result.record.executed)
        assertEquals("pc", result.record.approver?.device)
    }

    @Test
    fun a_denial_keeps_the_device_that_denied() = runBlocking {
        val harness = Harness(PhoneDeny())
        val result = harness.execute(Action(kind = "payment.pay", text = "100", ref = "pay-button"))

        assertEquals(false, result.record.executed)
        assertEquals(false, result.record.approved)
        assertEquals("phone", result.record.approver?.device)
        assertEquals("E_REFUSED", result.record.error)
    }

    @Test
    fun an_action_without_approval_has_no_approver() = runBlocking {
        val harness = Harness(PhoneApproval())
        val result = harness.execute(Action(kind = "ui.tap", ref = "e1"))

        assertNull(result.record.approver)
    }

    private class PhoneApproval : ApprovalGateway {
        override suspend fun approve(request: ApprovalRequest): Boolean = true
        override suspend fun decide(request: ApprovalRequest) = ApprovalDecision(true, "phone")
    }

    private class PcApproval : ApprovalGateway {
        override suspend fun approve(request: ApprovalRequest): Boolean = true
    }

    private class PhoneDeny : ApprovalGateway {
        override suspend fun approve(request: ApprovalRequest): Boolean = false
        override suspend fun decide(request: ApprovalRequest) = ApprovalDecision(false, "phone")
    }

    private class Harness(approval: ApprovalGateway) {
        private val clock = FakeClock()
        private val recorder = InMemoryRunRecorder()
        private val device = FakeDevice()
        private val executor = ActionExecutor(
            device = device,
            browser = null,
            system = object : SystemPort {
                override suspend fun openLink(url: String) = Unit
                override suspend fun setAlarm(hour: Int, minute: Int, label: String) = Unit
                override suspend fun addEvent(title: String, startMillis: Long, endMillis: Long) = Unit
                override suspend fun share(text: String) = Unit
                override suspend fun sendMessage(target: String, text: String) = Unit
                override suspend fun call(number: String) = Unit
                override suspend fun delete(query: String) = Unit
                override suspend fun uninstall(packageName: String) = Unit
            },
            sandbox = null,
            policy = { ApprovalPolicy() },
            approval = approval,
            recorder = recorder,
            factory = RunRecordFactory(clock),
            clock = clock,
        )

        suspend fun execute(action: Action) = executor.execute(
            runId = "run-provenance",
            step = 0,
            traceId = "trace-provenance",
            action = action,
            before = Observation(
                id = "obs",
                timestamp = 0,
                screenSize = ScreenSize(1080, 2400),
                text = "screen",
                tree = ObservationNode(type = "root"),
            ),
        )
    }
}
