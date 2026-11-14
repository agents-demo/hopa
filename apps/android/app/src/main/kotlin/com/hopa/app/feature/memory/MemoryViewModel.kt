package com.hopa.app.feature.memory

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.app.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class MemoryViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val _state = MutableStateFlow(MemoryUiState())
    val state: StateFlow<MemoryUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { load() }
    }

    fun addFact(text: String) {
        if (text.isBlank()) {
            return
        }
        viewModelScope.launch {
            container.memory.add(text)
            load()
        }
    }

    fun deleteFact(text: String) {
        viewModelScope.launch {
            container.memory.delete(text)
            load()
        }
    }

    fun addSkill(trigger: String, action: String) {
        if (trigger.isBlank() || action.isBlank()) {
            return
        }
        viewModelScope.launch {
            container.skills.add(trigger, action)
            load()
        }
    }

    fun deleteSkill(trigger: String) {
        viewModelScope.launch {
            container.skills.delete(trigger)
            load()
        }
    }

    fun clearAll() {
        viewModelScope.launch {
            container.memory.clear()
            container.skills.clear()
            load()
        }
    }

    private suspend fun load() {
        _state.update {
            it.copy(
                facts = container.memory.all(),
                skills = container.skills.all(),
                busy = false,
            )
        }
    }
}
