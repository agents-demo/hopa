package com.hopa.core.gate

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.RiskLevel
import com.hopa.policy.ApprovalPolicyData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** One assertion per policy list, so a generated list cannot drift unnoticed. */
class ApprovalPolicyCasesTest {
    private val policy = ApprovalPolicy()

    @Test
    fun every_payment_kind_is_a_payment_and_always_asks() {
        for (kind in ApprovalPolicyData.PAYMENT_KINDS) {
            val action = Action(kind = kind)
            assertEquals(kind, RiskLevel.PAYMENT, policy.classify(action))
            assertTrue(kind, policy.requiresApproval(action))
        }
    }

    @Test
    fun an_autonomous_run_still_asks_for_a_payment() {
        val autonomous = ApprovalPolicy()
        autonomous.setAutonomous(true)
        val payment = Action(kind = ApprovalPolicyData.PAYMENT_KINDS.first())
        assertTrue(autonomous.requiresApproval(payment))
        val allowed = Action(kind = ApprovalPolicyData.ALLOWED_KINDS.first())
        assertFalse(autonomous.requiresApproval(allowed))
    }

    @Test
    fun every_sensitive_kind_asks() {
        for (kind in ApprovalPolicyData.SENSITIVE_KINDS) {
            assertTrue(kind, policy.requiresApproval(Action(kind = kind)))
            assertTrue(kind, policy.classify(Action(kind = kind)) != RiskLevel.READ)
        }
    }

    @Test
    fun every_allowed_kind_runs_without_asking() {
        for (kind in ApprovalPolicyData.ALLOWED_KINDS) {
            assertFalse(kind, policy.requiresApproval(Action(kind = kind)))
        }
    }

    @Test
    fun an_unknown_kind_fails_closed() {
        val action = Action(kind = "ui.teleport")
        assertTrue(policy.requiresApproval(action))
        assertEquals(RiskLevel.SENSITIVE, policy.classify(action))
    }
}
