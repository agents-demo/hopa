package com.hopa.core.parser

import com.hopa.core.contracts.Decision
import com.hopa.core.contracts.HopaError

data class ParseOutcome(
    val decision: Decision? = null,
    val text: String? = null,
    val error: HopaError? = null,
)
