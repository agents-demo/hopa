package com.hopa.core.contracts

import kotlinx.serialization.Serializable

@Serializable
data class ObservationNode(
    val ref: String = "",
    val type: String = "",
    val text: String = "",
    val description: String = "",
    val id: String = "",
    val bounds: List<Int>? = null,
    val clickable: Boolean = false,
    val enabled: Boolean = true,
    val checked: Boolean = false,
    val scrollable: Boolean = false,
    val visible: Boolean = true,
    val focused: Boolean = false,
    val children: List<ObservationNode> = emptyList(),
)
