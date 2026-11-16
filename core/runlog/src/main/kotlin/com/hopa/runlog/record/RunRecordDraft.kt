package com.hopa.runlog.record

import com.hopa.contracts.wire.Action

data class RunRecordDraft(
    val runId: String,
    val step: Int,
    val timestamp: String? = null,
    val traceId: String,
    val action: Action,
    val classification: String,
    val tier: String = "",
    val approved: Boolean? = null,
    val observationHash: String,
    val beforeHash: String? = null,
    val afterHash: String? = null,
    val targetKey: String? = null,
    val verified: Boolean,
    val executed: Boolean,
    val error: String? = null,
)
