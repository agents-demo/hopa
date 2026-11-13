package com.hopa.core.contracts

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Observation(
    @SerialName("schemaVersion") val schemaVersion: String = "1",
    val id: String,
    val timestamp: Long,
    @SerialName("displayId") val displayId: Int = 0,
    @SerialName("windowId") val windowId: String = "active",
    val rotation: Int = 0,
    val density: Float = 1.0f,
    @SerialName("screenSize") val screenSize: ScreenSize,
    val focus: String = "",
    val text: String = "",
    val tree: ObservationNode,
    @SerialName("screenshotRef") val screenshotRef: String = "",
    val app: String = "",
    val hash: String = "",
    val truncated: Boolean = false,
)
