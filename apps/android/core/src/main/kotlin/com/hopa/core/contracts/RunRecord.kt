package com.hopa.core.contracts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RunRecord(
    @SerialName("schemaVersion") val schemaVersion: String = "1",
    val runId: String,
    val step: Int,
    val timestamp: String? = null,
    val traceId: String,
    val action: Action,
    val classification: String,
    val approved: Boolean? = null,
    @SerialName("observationHash") val observationHash: String,
    @SerialName("beforeHash") val beforeHash: String? = null,
    @SerialName("afterHash") val afterHash: String? = null,
    val verified: Boolean,
    val executed: Boolean,
    val error: String? = null,
    @SerialName("prevHash") val prevHash: String,
    val hash: String,
)
