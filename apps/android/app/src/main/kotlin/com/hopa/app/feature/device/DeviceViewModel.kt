package com.hopa.app.feature.device

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.accessibility.AccessibilityState
import com.hopa.capabilities.accessibility.HopaAccessibilityService
import com.hopa.capabilities.bridge.BridgeClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class DeviceViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val _state = MutableStateFlow(DeviceUiState())
    val state: StateFlow<DeviceUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { load() }
    }

    fun refresh() {
        viewModelScope.launch { load() }
    }

    fun checkBridge() {
        viewModelScope.launch {
            val current = container.settings.settings.first()
            val token = container.settings.bridgeToken()
            if (current.bridgeUrl.isBlank() || token.isBlank()) {
                _state.update {
                    it.copy(bridgeOk = null, bridgeError = "No bridge is configured")
                }
                return@launch
            }
            _state.update { it.copy(checking = true, bridgeError = null) }
            val result = runCatching {
                BridgeClient(current.bridgeUrl, token).health()
            }
            _state.update {
                it.copy(
                    checking = false,
                    bridgeOk = result.isSuccess,
                    bridgeError = result.exceptionOrNull()?.message,
                )
            }
        }
    }

    private suspend fun load() {
        val current = container.settings.settings.first()
        val token = container.settings.bridgeToken()
        _state.update {
            it.copy(
                bridgeUrl = current.bridgeUrl,
                bridgeConfigured = current.useBridge &&
                    current.bridgeUrl.isNotBlank() &&
                    token.isNotBlank(),
                accessibilityEnabled = AccessibilityState.isEnabled(container.context),
                accessibilityLive = HopaAccessibilityService.instance != null,
            )
        }
    }
}
