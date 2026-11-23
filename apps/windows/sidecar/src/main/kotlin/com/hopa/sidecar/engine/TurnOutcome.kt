package com.hopa.sidecar.engine

import com.hopa.contracts.wire.RunRecord

/** What one turn produced, as the protocol and the window see it. */
data class TurnOutcome(
    val conversationId: String,
    val title: String,
    val answer: String,
    val records: List<RunRecord>,
    val chainOk: Boolean,
    val narration: List<String> = emptyList(),
    val error: String? = null,
)
