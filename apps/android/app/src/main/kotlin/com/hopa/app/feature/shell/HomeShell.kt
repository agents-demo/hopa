package com.hopa.app.feature.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.app.feature.activity.ActivityRoute
import com.hopa.app.feature.capabilities.CapabilitiesRoute
import com.hopa.app.feature.chat.ChatRoute

/**
 * The three top-level pages from Index.ets. The tab state lives here, not in
 * the navigation graph, so switching tabs never stacks a back entry.
 */
@Composable
fun HomeShell(
    container: AppContainer,
    onOpenSettings: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onOpenMemory: () -> Unit,
    onOpenDevice: () -> Unit,
    initialGoal: String = "",
) {
    var tab by rememberSaveable { mutableStateOf("chat") }
    val selectTab: (String) -> Unit = { key ->
        if (key == "chat" || key == "activity" || key == "capabilities") {
            tab = key
        }
    }

    when (tab) {
        "activity" -> ActivityRoute(
            container = container,
            activeTab = tab,
            onSelectTab = selectTab,
            onOpenRuns = onOpenRuns,
            onOpenUsage = onOpenUsage,
        )

        "capabilities" -> CapabilitiesRoute(
            container = container,
            activeTab = tab,
            onSelectTab = selectTab,
            onOpenLaunchpad = onOpenLaunchpad,
            onOpenSettings = onOpenSettings,
            onOpenRuns = onOpenRuns,
            onOpenUsage = onOpenUsage,
            onOpenMemory = onOpenMemory,
            onOpenDevice = onOpenDevice,
        )

        else -> ChatRoute(
            container = container,
            activeTab = tab,
            onSelectTab = selectTab,
            initialGoal = initialGoal,
        )
    }
}
