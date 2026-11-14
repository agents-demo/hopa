package com.hopa.core.loop

data class LoopConfig(
    val maxSteps: Int = 14,
    val settleMillis: Long = 1_500,
)
