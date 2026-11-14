package com.hopa.app.feature.usage

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.app.di.AppContainer
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class UsageViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val _state = MutableStateFlow(UsageUiState())
    val state: StateFlow<UsageUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { load() }
    }

    fun refresh() {
        viewModelScope.launch { load() }
    }

    private suspend fun load() {
        val records = container.recorder.all()
        val cutoff = Instant.now().minus(7, ChronoUnit.DAYS)
        val recent = records.filter { record ->
            val timestamp = record.timestamp ?: return@filter true
            try {
                !Instant.parse(timestamp).isBefore(cutoff)
            } catch (error: Exception) {
                true
            }
        }
        val top = records.groupingBy { it.action.kind }.eachCount()
            .entries
            .sortedByDescending { it.value }
            .take(6)
            .map { it.key to it.value }
        _state.update {
            UsageUiState(
                total = records.size,
                executed = records.count { record -> record.executed },
                failed = records.count { record -> !record.executed },
                payments = records.count { record -> record.classification == "payment" },
                lastSevenDays = recent.size,
                topActions = top,
            )
        }
    }
}
