package com.hopa.core.loop

import com.hopa.core.contracts.HopaError
import com.hopa.core.contracts.RunRecord

data class TurnResult(
    val answer: String,
    val records: List<RunRecord> = emptyList(),
    val narration: List<String> = emptyList(),
    val options: List<String> = emptyList(),
    val error: HopaError? = null,
)
