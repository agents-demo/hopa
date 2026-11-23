package com.hopa.feature.execution

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.hilt.navigation.compose.hiltViewModel
import com.hopa.feature.execution.ExecutionDependencies
import com.hopa.feature.settings.SettingsViewModel

@Composable
fun RunPrefsRoute(
    onBack: () -> Unit,
) {
    val viewModel: SettingsViewModel = hiltViewModel()
    val state by viewModel.state.collectAsStateWithLifecycle()

    RunPrefsScreen(
        state = state,
        onBack = onBack,
        onPlanFirst = viewModel::setPlanFirst,
        onVision = viewModel::setVision,
        onReplaySkills = viewModel::setReplaySkills,
        onCloudFallback = viewModel::setCloudFallback,
    )
}
