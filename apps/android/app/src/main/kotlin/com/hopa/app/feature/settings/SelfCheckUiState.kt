package com.hopa.app.feature.settings

data class SelfCheckUiState(
    val provider: String = "",
    val model: String = "",
    val bridgeUrl: String = "",
    val bridgeOk: Boolean? = null,
    val accessibilityEnabled: Boolean = false,
    val accessibilityLive: Boolean = false,
    val sessions: Int = 0,
    val records: Int = 0,
    val facts: Int = 0,
    val skills: Int = 0,
    val checking: Boolean = false,
)
