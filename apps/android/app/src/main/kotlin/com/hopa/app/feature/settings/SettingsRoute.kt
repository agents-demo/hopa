package com.hopa.app.feature.settings

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer

@Composable
fun SettingsRoute(
    container: AppContainer,
    onBack: () -> Unit,
    onOpenCapabilities: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenProfiles: () -> Unit,
) {
    val viewModel: SettingsViewModel = viewModel(factory = SettingsViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    SettingsScreen(
        state = state,
        onBack = onBack,
        onSave = viewModel::save,
        onTestBridge = viewModel::testBridge,
        onOpenCapabilities = onOpenCapabilities,
        onOpenLaunchpad = onOpenLaunchpad,
        onOpenProfiles = onOpenProfiles,
    )
}
