package com.hopa.core.records

import com.hopa.core.contracts.Action

data class RunRecordDraft(
    val runId: String,
    val step: Int,
    val timestamp: String? = null,
    val traceId: String,
    val action: Action,
    val classification: String,
    val approved: Boolean? = null,
    val observationHash: String,
    val beforeHash: String? = null,
    val afterHash: String? = null,
    val verified: Boolean,
    val executed: Boolean,
    val error: String? = null,
)
