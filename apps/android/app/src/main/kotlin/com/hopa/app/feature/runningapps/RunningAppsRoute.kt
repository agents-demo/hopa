package com.hopa.app.feature.runningapps

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer
import com.hopa.app.feature.settings.SettingsViewModel
import com.hopa.app.feature.settings.SettingsViewModelFactory

/** The Act hub: how HOPA acts, and the ways into apps, setup and preferences. */
@Composable
fun RunningAppsRoute(
    container: AppContainer,
    onBack: () -> Unit,
    onOpenHowHopaActs: () -> Unit,
    onOpenAllApps: () -> Unit,
    onOpenSites: () -> Unit,
    onOpenSetup: () -> Unit,
    onOpenRunPrefs: () -> Unit,
) {
    val viewModel: SettingsViewModel = viewModel(factory = SettingsViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(3_000)
            viewModel.refreshBackground()
        }
    }

    // Screen access is granted in Android settings and binds a moment later, so
    // the pill is re-read on resume and while this page stays open.
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(2_000)
            viewModel.refreshScreenAccess()
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
                viewModel.refreshScreenAccess()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    RunningAppsScreen(
        state = state,
        onBack = onBack,
        onOpenHowHopaActs = onOpenHowHopaActs,
        onOpenSetup = onOpenSetup,
        onOpenRunPrefs = onOpenRunPrefs,
        onOpenAllApps = onOpenAllApps,
        onOpenSites = onOpenSites,
    )
}
