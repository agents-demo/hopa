package com.hopa.contracts.wire

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable(with = RunRecordSerializer::class)
data class RunRecord(
    @SerialName("schemaVersion") val schemaVersion: String = "1",
    val runId: String,
    val step: Int,
    val timestamp: String? = null,
    val traceId: String,
    val action: Action,
    val classification: String,
    /** Which path reached the app: api, intent, uia or input (empty when unknown). */
    val tier: String = "",
    val approved: Boolean? = null,
    @SerialName("observationHash") val observationHash: String,
    @SerialName("beforeHash") val beforeHash: String? = null,
    @SerialName("afterHash") val afterHash: String? = null,
    /**
     * What the tapped node was, not where it was: text, description, id and type,
     * so a recipe can find the same control after the tree has moved.
     */
    @SerialName("targetKey") val targetKey: String? = null,
    val verified: Boolean,
    val executed: Boolean,
    val error: String? = null,
    @SerialName("prevHash") val prevHash: String,
    val hash: String,
)
