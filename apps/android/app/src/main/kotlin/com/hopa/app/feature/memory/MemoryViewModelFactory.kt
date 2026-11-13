package com.hopa.app.feature.memory

import androidx.lifecycle.ViewModelProvider
import com.hopa.app.di.AppContainer

class MemoryViewModelFactory(
    private val container: AppContainer,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
        MemoryViewModel(container) as T
}
