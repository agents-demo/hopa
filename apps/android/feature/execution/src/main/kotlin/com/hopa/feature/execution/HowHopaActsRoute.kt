package com.hopa.feature.execution

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.hilt.navigation.compose.hiltViewModel
import com.hopa.feature.execution.ExecutionDependencies
import com.hopa.feature.settings.SettingsViewModel

@Composable
fun HowHopaActsRoute(
    container: ExecutionDependencies,
    onBack: () -> Unit,
    onOpenScreenAccess: () -> Unit,
    onOpenComputer: () -> Unit,
    onOpenSetup: () -> Unit,
    onOpenDecisions: () -> Unit,
    onOpenAnswers: () -> Unit,
) {
    val viewModel: SettingsViewModel = hiltViewModel()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val pairing by container.pairingStatus.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current

    // The supervisor owns the helper's state and publishes it; the page reads it
    // once when it opens and follows the flow after that.
    LaunchedEffect(Unit) { viewModel.refreshBackground() }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refresh()
                viewModel.refreshBackground()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    HowHopaActsScreen(
        state = state,
        pairingStatus = pairing,
        onBack = onBack,
        onScreenPath = viewModel::setScreenPath,
        onStartBackgroundHelper = viewModel::startBackgroundHelper,
        onTestBridge = viewModel::testBridge,
        onPairWireless = viewModel::pairWireless,
        onPairWirelessFromScreen = viewModel::pairWirelessFromScreen,
        onPairWirelessWaiting = viewModel::pairWirelessWaiting,
        onOpenScreenAccess = onOpenScreenAccess,
        onOpenComputer = onOpenComputer,
        onOpenSetup = onOpenSetup,
        onOpenDecisions = onOpenDecisions,
        onStepSource = viewModel::setStepSource,
        onTreeRanker = viewModel::setTreeRanker,
        onProvider = viewModel::selectProvider,
        onLocalModel = viewModel::selectLocalModel,
        onOpenAnswers = onOpenAnswers,
    )
}
