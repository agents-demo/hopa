package com.hopa.app.feature.settings

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.accessibility.AccessibilityState
import com.hopa.capabilities.accessibility.HopaAccessibilityService
import com.hopa.capabilities.bridge.BridgeClient
import com.hopa.capabilities.llm.ProviderState
import com.hopa.capabilities.llm.ProviderStateResolver
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@Composable
fun SelfCheckRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    var state by remember { mutableStateOf(SelfCheckUiState()) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        state = collect(container)
    }

    SelfCheckScreen(
        state = state,
        onBack = onBack,
        onRetry = {
            scope.launch {
                state = state.copy(checking = true)
                state = collect(container)
            }
        },
    )
}

private suspend fun collect(container: AppContainer): SelfCheckUiState {
    val settings = container.settings.settings.first()
    val key = container.settings.modelKey()
    val token = container.settings.bridgeToken()
    val provider = ProviderStateResolver().resolve(settings.provider, settings.endpoint, key)
    val bridgeOk = if (settings.bridgeUrl.isNotBlank() && token.isNotBlank()) {
        runCatching { BridgeClient(settings.bridgeUrl, token).health() }.isSuccess
    } else {
        null
    }
    return SelfCheckUiState(
        provider = settings.provider,
        model = provider.label(),
        bridgeUrl = settings.bridgeUrl,
        bridgeOk = bridgeOk,
        accessibilityEnabled = AccessibilityState.isEnabled(container.context),
        accessibilityLive = HopaAccessibilityService.instance != null,
        sessions = runCatching { container.conversations.all().size }.getOrDefault(0),
        records = runCatching { container.recorder.all().size }.getOrDefault(0),
        facts = runCatching { container.memory.all().size }.getOrDefault(0),
        skills = runCatching { container.skills.all().size }.getOrDefault(0),
        checking = false,
    )
}


private fun ProviderState.label(): String = when (this) {
    ProviderState.CLOUD -> "Cloud model"
    ProviderState.LAN -> "LAN model"
    ProviderState.DEMO -> "Demo model (no key)"
    ProviderState.NO_MODEL -> "No model"
}
