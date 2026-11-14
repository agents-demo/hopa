package com.hopa.app.feature.device

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer

import kotlinx.coroutines.delay

@Composable
fun DeviceRoute(
    container: AppContainer,
    onBack: () -> Unit,
    onOpenBridgeSettings: () -> Unit,
    onOpenAccessibility: () -> Unit,
) {
    val viewModel: DeviceViewModel = viewModel(factory = DeviceViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        while (true) {
            viewModel.refresh()
            delay(2_000)
        }
    }

    DeviceScreen(
        state = state,
        onBack = onBack,
        onRetry = viewModel::checkBridge,
        onOpenBridgeSettings = onOpenBridgeSettings,
        onOpenAccessibility = onOpenAccessibility,
    )
}
