package com.hopa.sidecar.turn

import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.model.ModelRequest
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The scripted model is a proposer. These tests defend that it never presents
 * itself as an approval and never invents a success after a refusal.
 */
class ScriptedModelTest {
    @Test
    fun a_plain_goal_is_answered_in_text() {
        val reply = reply(ModelMessage("user", "say hello"))

        assertTrue(reply.text.startsWith("Stub answered"))
        assertFalse(reply.text.contains("{"), "a plain answer must not look like an action")
    }

    @Test
    fun a_payment_goal_is_only_proposed() {
        val text = reply(ModelMessage("user", "pay 100 for the order")).text

        assertTrue(text.contains("\"payment.pay\""))
        assertFalse(text.contains("approved"), "the stub cannot approve anything")
        assertFalse(text.contains("allow"), "the stub cannot allow anything")
    }

    @Test
    fun a_refusal_is_echoed_verbatim() {
        val text = reply(
            ModelMessage("user", "pay 100 for the order"),
            ModelMessage("assistant", """{"kind":"payment.pay"}"""),
            ModelMessage("user", "I did not run that."),
        ).text

        assertEquals("I did not run that.", text)
    }

    @Test
    fun a_device_failure_is_echoed_verbatim() {
        val text = reply(
            ModelMessage("user", "click the save button"),
            ModelMessage("assistant", """{"kind":"ui.tap"}"""),
            ModelMessage("user", "I could not do that: no device is attached"),
        ).text

        assertEquals("I could not do that: no device is attached", text)
    }

    @Test
    fun an_action_is_not_proposed_twice() {
        val text = reply(
            ModelMessage("user", "click the save button"),
            ModelMessage("assistant", """{"kind":"ui.tap","x":700,"y":600}"""),
        ).text

        assertFalse(text.contains("\"ui.tap\""))
        assertTrue(text.startsWith("Stub answered"))
    }

    private fun reply(vararg messages: ModelMessage) =
        runBlocking { ScriptedModel().complete(ModelRequest(messages.toList())) }
}
