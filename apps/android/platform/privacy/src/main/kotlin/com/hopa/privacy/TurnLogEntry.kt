package com.hopa.privacy

/** One record of what a turn sent and did. Nothing here holds screen text. */
data class TurnLogEntry(
    val at: Long,
    val path: String,
    val steps: Int,
    val tokens: Int,
    val charactersSent: Int,
    val goal: String,
)
