package com.hopa.app.feature.device

data class DeviceUiState(
    val bridgeUrl: String = "",
    val bridgeConfigured: Boolean = false,
    val bridgeOk: Boolean? = null,
    val bridgeError: String? = null,
    val accessibilityEnabled: Boolean = false,
    val accessibilityLive: Boolean = false,
    val checking: Boolean = false,
)
