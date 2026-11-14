package com.hopa.core.records

import com.hopa.core.contracts.Action
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RunChainTest {
    private fun draft(step: Int) = RunRecordDraft(
        runId = "run-1",
        step = step,
        traceId = "trace-1",
        action = Action(kind = "ui.tap", ref = "e2"),
        classification = "read",
        approved = null,
        observationHash = "sha256:" + "1".repeat(64),
        verified = true,
        executed = true,
    )

    @Test
    fun seals_and_verifies_a_chain() {
        val first = RunChain.seal(draft(0), RunChain.SEED)
        val second = RunChain.seal(draft(1), first.hash)
        assertTrue(RunChain.verify(listOf(first, second)))
    }

    @Test
    fun a_tampered_record_fails() {
        val first = RunChain.seal(draft(0), RunChain.SEED)
        val tampered = first.copy(classification = "payment")
        assertFalse(RunChain.verify(listOf(tampered)))
    }
}
