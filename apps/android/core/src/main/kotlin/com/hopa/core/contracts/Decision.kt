package com.hopa.core.contracts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Decision(
    val action: Action? = null,
    val say: String,
    val done: Boolean,
    @SerialName("needUser") val needUser: Boolean,
    val options: List<String>? = null,
    val sessionId: String? = null,
    val version: String? = null,
)
