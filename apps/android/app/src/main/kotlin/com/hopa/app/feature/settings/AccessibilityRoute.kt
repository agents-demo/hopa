package com.hopa.app.feature.settings

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.accessibility.AccessibilityState
import com.hopa.capabilities.accessibility.HopaAccessibilityService
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@Composable
fun AccessibilityRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var allowed by remember { mutableStateOf(true) }
    var serviceEnabled by remember { mutableStateOf(false) }
    var connected by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        allowed = container.settings.settings.first().accessibilityAllowed
    }
    LaunchedEffect(Unit) {
        while (true) {
            serviceEnabled = AccessibilityState.isEnabled(context)
            connected = HopaAccessibilityService.instance != null
            delay(1_500)
        }
    }

    AccessibilityScreen(
        allowed = allowed,
        serviceEnabled = serviceEnabled,
        connected = connected,
        onToggle = { value ->
            allowed = value
            scope.launch {
                container.settings.update { it.copy(accessibilityAllowed = value) }
            }
        },
        onOpenSettings = { AccessibilityState.openSettings(context) },
        onBack = onBack,
    )
}
