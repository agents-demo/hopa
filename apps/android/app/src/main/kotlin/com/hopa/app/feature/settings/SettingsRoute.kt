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
    onOpenAccessibility: () -> Unit,
    onOpenSelfCheck: () -> Unit,
    onOpenAbout: () -> Unit,
) {
    val viewModel: SettingsViewModel = viewModel(factory = SettingsViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    SettingsScreen(
        state = state,
        onBack = onBack,
        onSave = viewModel::save,
        onTestBridge = viewModel::testBridge,
        onTestNotification = viewModel::testNotification,
        onTone = viewModel::setTone,
        onChattiness = viewModel::setChattiness,
        onOpenSelfCheck = onOpenSelfCheck,
        onOpenAbout = onOpenAbout,
        onPairBridge = viewModel::pairBridge,
        onOpenCapabilities = onOpenCapabilities,
        onOpenLaunchpad = onOpenLaunchpad,
        onOpenProfiles = onOpenProfiles,
        onOpenAccessibility = onOpenAccessibility,
    )
}
