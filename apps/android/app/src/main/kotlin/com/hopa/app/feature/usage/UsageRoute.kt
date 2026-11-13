package com.hopa.app.feature.usage

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer

@Composable
fun UsageRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    val viewModel: UsageViewModel = viewModel(factory = UsageViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    UsageScreen(state = state, onBack = onBack)
}
