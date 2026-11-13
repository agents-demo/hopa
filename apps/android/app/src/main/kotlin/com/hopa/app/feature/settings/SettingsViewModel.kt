package com.hopa.app.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.llm.ProviderStateResolver
import com.hopa.data.settings.AppSettings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class SettingsViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val resolver = ProviderStateResolver()
    private val _state = MutableStateFlow(SettingsUiState())
    val state: StateFlow<SettingsUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { reload() }
    }

    fun save(
        provider: String,
        endpoint: String,
        model: String,
        key: String,
        notifyAnswers: Boolean,
        webEnabled: Boolean,
    ) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, saved = false, error = null) }
            runCatching {
                container.settings.update {
                    it.copy(
                        provider = provider.trim(),
                        endpoint = endpoint.trim(),
                        model = model.trim(),
                        notifyAnswers = notifyAnswers,
                        webEnabled = webEnabled,
                    )
                }
                if (key.isNotBlank()) {
                    container.settings.setModelKey(key.trim())
                }
                reload()
                _state.update { it.copy(saved = true) }
            }.onFailure { error ->
                _state.update { it.copy(error = error.message ?: "Could not save") }
            }
            _state.update { it.copy(busy = false) }
        }
    }

    private suspend fun reload() {
        val settings: AppSettings = container.settings.settings.first()
        val key = container.settings.modelKey()
        _state.update {
            it.copy(
                settings = settings,
                key = key,
                providerState = resolver.resolve(settings.provider, settings.endpoint, key),
            )
        }
    }
}
