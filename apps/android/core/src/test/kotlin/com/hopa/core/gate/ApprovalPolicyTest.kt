package com.hopa.core.gate

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.RiskLevel
import com.hopa.core.contracts.ScreenSize
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ApprovalPolicyTest {
    private val policy = ApprovalPolicy()

    private fun screen(text: String): Observation = Observation(
        id = "obs-test",
        timestamp = 1,
        screenSize = ScreenSize(1080, 2400),
        text = text,
        tree = ObservationNode(type = "root"),
    )

    @Test
    fun payment_kind_always_asks() {
        val action = Action(kind = "payment.checkout")
        assertEquals(RiskLevel.PAYMENT, policy.classify(action))
        assertTrue(policy.requiresApproval(action))
    }

    @Test
    fun a_tap_on_a_payment_screen_asks() {
        val action = Action(kind = "ui.tap", ref = "e2")
        val observation = screen("Checkout\nTotal Â¥19.99\nPay now")
        assertEquals(RiskLevel.PAYMENT, policy.classify(action, observation))
        assertTrue(policy.requiresApproval(action, observation))
    }

    @Test
    fun a_read_action_on_a_payment_screen_does_not_ask() {
        val action = Action(kind = "web.navigate", url = "https://example.com")
        val observation = screen("Checkout\nTotal Â¥19.99\nPay now")
        assertEquals(RiskLevel.READ, policy.classify(action, observation))
        assertFalse(policy.requiresApproval(action, observation))
    }

    @Test
    fun sensitive_and_unknown_actions_ask() {
        assertTrue(policy.requiresApproval(Action(kind = "system.delete")))
        assertTrue(policy.requiresApproval(Action(kind = "custom.unknown")))
    }

    @Test
    fun a_trusted_app_skips_the_message_prompt() {
        policy.setTrustedApps(listOf("com.example.chat"))
        val action = Action(kind = "system.sendMessage", app = "com.example.chat")
        assertEquals(RiskLevel.READ, policy.classify(action))
        assertFalse(policy.requiresApproval(action))
    }

    @Test
    fun extracts_amount_and_merchant() {
        val context = policy.extractPaymentContext(
            screen("Merchant: Blue Cafe\nAmount \$4.50"),
        )
        assertEquals("\$4.50", context.amount)
        assertEquals("Blue Cafe", context.merchant)
    }
}
