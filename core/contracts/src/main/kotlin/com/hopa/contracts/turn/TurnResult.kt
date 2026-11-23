package com.hopa.contracts.turn

import com.hopa.contracts.error.HopaError
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.wire.RunRecord

data class TurnResult(
    val answer: String,
    val records: List<RunRecord> = emptyList(),
    val narration: List<String> = emptyList(),
    val options: List<String> = emptyList(),
    val error: HopaError? = null,
    val usage: ModelUsage = ModelUsage(),
    /**
     * Which policies answered a step, in no particular order: "anchors",
     * "command", "model". The receipt names the path from this, not from a guess.
     */
    val sources: Set<String> = emptySet(),
)
