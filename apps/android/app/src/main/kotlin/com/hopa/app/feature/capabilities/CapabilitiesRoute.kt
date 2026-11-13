package com.hopa.app.feature.capabilities

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.accessibility.AccessibilityState
import com.hopa.capabilities.llm.ProviderState
import com.hopa.capabilities.llm.ProviderStateResolver
import kotlinx.coroutines.flow.first

@Composable
fun CapabilitiesRoute(
    container: AppContainer,
    onBack: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    var provider by remember { mutableStateOf(ProviderState.DEMO) }
    var endpoint by remember { mutableStateOf("") }
    var records by remember { mutableStateOf(0) }
    var apps by remember { mutableStateOf(0) }
    var accessibilityEnabled by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val settings = container.settings.settings.first()
        val key = container.settings.modelKey()
        provider = ProviderStateResolver().resolve(settings.provider, settings.endpoint, key)
        endpoint = settings.endpoint
        records = container.recorder.all().size
        apps = container.packages.installed().size
        accessibilityEnabled = AccessibilityState.isEnabled(container.context)
    }

    CapabilitiesScreen(
        provider = provider,
        endpoint = endpoint,
        records = records,
        apps = apps,
        accessibilityEnabled = accessibilityEnabled,
        onBack = onBack,
        onOpenLaunchpad = onOpenLaunchpad,
        onOpenSettings = onOpenSettings,
        onOpenAccessibility = { AccessibilityState.openSettings(container.context) },
    )
}
