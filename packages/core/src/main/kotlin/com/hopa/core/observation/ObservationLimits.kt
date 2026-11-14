package com.hopa.core.observation

/** The numbers from `contracts/observation/limits.v1.json`. */
data class ObservationLimits(
    val maxNodes: Int = 400,
    val maxTextChars: Int = 6_000,
    val maxElementLines: Int = 120,
    val maxBrowserTextChars: Int = 20_000,
)
