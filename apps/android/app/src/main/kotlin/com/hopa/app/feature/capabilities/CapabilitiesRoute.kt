package com.hopa.app.feature.capabilities

import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.accessibility.AccessibilityState
import com.hopa.capabilities.llm.ProviderState
import com.hopa.capabilities.llm.ProviderStateResolver
import kotlinx.coroutines.flow.first

@Composable
fun CapabilitiesRoute(
    container: AppContainer,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onOpenMemory: () -> Unit,
    onOpenDevice: () -> Unit,
) {
    var provider by remember { mutableStateOf(ProviderState.DEMO) }
    var endpoint by remember { mutableStateOf("") }
    var records by remember { mutableStateOf(0) }
    var apps by remember { mutableStateOf(0) }
    var facts by remember { mutableStateOf(0) }
    var skills by remember { mutableStateOf(0) }
    var accessibilityEnabled by remember { mutableStateOf(false) }
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        val settings = container.settings.settings.first()
        val key = container.settings.modelKey()
        provider = ProviderStateResolver().resolve(settings.provider, settings.endpoint, key)
        endpoint = settings.endpoint
        records = container.recorder.all().size
        apps = container.packages.installed().size
        facts = container.memory.all().size
        skills = container.skills.all().size
        accessibilityEnabled = AccessibilityState.isEnabled(container.context)
    }

    CapabilitiesScreen(
        provider = provider,
        endpoint = endpoint,
        records = records,
        apps = apps,
        facts = facts,
        skills = skills,
        accessibilityEnabled = accessibilityEnabled,
        activeTab = activeTab,
        onSelectTab = onSelectTab,
        onOpenLaunchpad = onOpenLaunchpad,
        onOpenSettings = onOpenSettings,
        onOpenDevice = onOpenDevice,
        onOpenRuns = onOpenRuns,
        onOpenUsage = onOpenUsage,
        onOpenMemory = onOpenMemory,
        onUnavailable = { feature ->
            Toast.makeText(
                context,
                "$feature is not on Android yet.",
                Toast.LENGTH_SHORT,
            ).show()
        },
    )
}
