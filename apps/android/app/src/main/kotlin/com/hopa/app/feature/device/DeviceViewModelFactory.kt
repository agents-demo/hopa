package com.hopa.app.feature.device

import androidx.lifecycle.ViewModelProvider
import com.hopa.app.di.AppContainer

class DeviceViewModelFactory(
    private val container: AppContainer,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
        DeviceViewModel(container) as T
}
