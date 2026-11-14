package com.hopa.app.feature.settings

import com.hopa.capabilities.llm.ProviderState
import com.hopa.data.settings.AppSettings

data class SettingsUiState(
    val settings: AppSettings = AppSettings(),
    val key: String = "",
    val bridgeKey: String = "",
    val providerState: ProviderState = ProviderState.DEMO,
    val busy: Boolean = false,
    val saved: Boolean = false,
    val error: String? = null,
    val bridgeStatus: String? = null,
    val notice: String? = null,
)
