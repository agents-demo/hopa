package com.hopa.sidecar

import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.RunRecord
import com.hopa.sidecar.Protocol.text
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

/** P0 froze these shapes; P1 emits and refuses them. */
class ProtocolTest {
    @Test
    fun step_carries_the_gate_outcome() {
        val record = RunRecord(
            runId = "run-t",
            step = 0,
            traceId = "trace",
            action = Action(kind = "payment.pay", app = "bank", text = "100"),
            classification = "payment",
            tier = "uia",
            approved = false,
            observationHash = "sha256:before",
            beforeHash = "sha256:before",
            afterHash = "sha256:before",
            verified = false,
            executed = false,
            error = "E_REFUSED",
            prevHash = "sha256:seed",
            hash = "sha256:record",
        )

        val step = Protocol.step("t-1", 3, record, at = 1_763_000_000_000, durationMs = 41)

        assertEquals("step", step.text("type"))
        assertEquals("t-1", step.text("id"))
        assertEquals("3", step.text("index"))
        assertEquals("payment.pay", step.text("action"))
        assertEquals("payment", step.text("classification"))
        assertEquals("uia", step.text("tier"))
        assertEquals("false", step["approved"].toString())
        assertEquals("false", step["executed"].toString())
        assertEquals("E_REFUSED", step.text("error"))
    }

    @Test
    fun an_unapproved_action_has_a_null_approval() {
        val record = RunRecord(
            runId = "run-t",
            step = 0,
            traceId = "trace",
            action = Action(kind = "ui.tap", x = 1, y = 2),
            classification = "read",
            approved = null,
            observationHash = "sha256:before",
            beforeHash = "sha256:before",
            afterHash = "sha256:after",
            verified = true,
            executed = true,
            error = null,
            prevHash = "sha256:seed",
            hash = "sha256:record",
        )

        val step = Protocol.step("t-2", 0, record, at = 0, durationMs = 5)

        assertEquals("null", step["approved"].toString())
        assertEquals("null", step["error"].toString())
    }

    @Test
    fun task_messages_are_refused_not_ignored() {
        val refusal = Protocol.taskRefused("r-1", "task.handoff", "not yet")

        assertEquals("task.error", refusal.text("type"))
        assertEquals("r-1", refusal.text("id"))
        assertEquals("task.handoff", refusal.text("request"))
        assertEquals("false", refusal["ok"].toString())
        assertEquals("E_UNSUPPORTED", refusal.text("code"))
        assertEquals("not yet", refusal.text("error"))
    }

    @Test
    fun an_unknown_cli_option_is_rejected() {
        assertThrows(IllegalArgumentException::class.java) {
            CliOptions.parse(arrayOf("--allow-everything"))
        }
    }

    @Test
    fun the_cli_parses_the_headless_contract() {
        val options = CliOptions.parse(
            arrayOf("--turn", "say hello", "--data-dir", "C:\\tmp\\hopa", "--conversation", "c-1"),
        )

        assertEquals("say hello", options.turn)
        assertEquals("C:\\tmp\\hopa", options.dataDir.toString())
        assertEquals("c-1", options.conversationId)
    }
}
