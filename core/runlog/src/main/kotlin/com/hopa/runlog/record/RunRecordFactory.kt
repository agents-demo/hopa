package com.hopa.runlog.record

import com.hopa.contracts.json.ObservationHasher
import com.hopa.contracts.ports.Clock
import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.Approver
import com.hopa.contracts.wire.Observation
import java.time.Instant

class RunRecordFactory(
    private val clock: Clock,
) {
    fun draft(
        runId: String,
        step: Int,
        traceId: String,
        action: Action,
        classification: String,
        tier: String = "",
        approved: Boolean?,
        approver: Approver? = null,
        observation: Observation,
        beforeHash: String?,
        afterHash: String?,
        verified: Boolean,
        executed: Boolean,
        targetKey: String? = null,
        error: String? = null,
    ): RunRecordDraft = RunRecordDraft(
        runId = runId,
        step = step,
        timestamp = Instant.ofEpochMilli(clock.nowMillis()).toString(),
        traceId = traceId,
        action = action,
        classification = classification,
        tier = tier,
        approved = approved,
        approver = approver,
        observationHash = ObservationHasher.hashOf(observation),
        beforeHash = beforeHash,
        afterHash = afterHash,
        targetKey = targetKey,
        verified = verified,
        executed = executed,
        error = error,
    )
}
