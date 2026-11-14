package com.hopa.core.contracts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Action(
    @SerialName("schemaVersion") val schemaVersion: String = "1",
    val kind: String,
    val ref: String? = null,
    val text: String? = null,
    val x: Int? = null,
    val y: Int? = null,
    @SerialName("toX") val toX: Int? = null,
    @SerialName("toY") val toY: Int? = null,
    val app: String? = null,
    val url: String? = null,
    val direction: String? = null,
    @SerialName("timeoutMs") val timeoutMs: Int = 3000,
) {
    fun kindOrNull(): ActionKind? = ActionKind.fromWire(kind)
}
