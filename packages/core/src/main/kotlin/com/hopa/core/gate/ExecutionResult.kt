package com.hopa.core.gate

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.RunRecord

data class ExecutionResult(
    val record: RunRecord,
    val observation: Observation,
    val text: String = "",
)
