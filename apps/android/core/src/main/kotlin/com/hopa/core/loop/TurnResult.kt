package com.hopa.core.loop

import com.hopa.core.contracts.HopaError
import com.hopa.core.contracts.RunRecord
import com.hopa.core.model.ModelUsage

data class TurnResult(
    val answer: String,
    val records: List<RunRecord> = emptyList(),
    val narration: List<String> = emptyList(),
    val options: List<String> = emptyList(),
    val error: HopaError? = null,
    val usage: ModelUsage = ModelUsage(),
)
