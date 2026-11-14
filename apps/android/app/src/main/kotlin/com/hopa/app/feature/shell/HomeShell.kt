package com.hopa.app.feature.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hopa.app.di.AppContainer
import com.hopa.app.feature.activity.ActivityRoute
import com.hopa.app.feature.capabilities.CapabilitiesRoute
import com.hopa.app.feature.chat.ChatRoute
import com.hopa.app.feature.conversations.EasyHistoryRoute
import com.hopa.app.feature.power.PowerHomeRoute
import com.hopa.data.settings.AppSettings

/**
 * The three top-level pages from Index.ets. The tab state lives here, not in
 * the navigation graph, so switching tabs never stacks a back entry.
 *
 * The Easy profile gets its own bar (Talk / History / Settings), as on Harmony.
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
    onOpenBrowser: () -> Unit,
    initialGoal: String = "",
) {
    val settings by container.settings.settings.collectAsStateWithLifecycle(
        initialValue = AppSettings(),
    )
    if (settings.profile == "easy") {
        EasyShell(
            container = container,
            onOpenSettings = onOpenSettings,
            initialGoal = initialGoal,
        )
        return
    }
    if (settings.profile == "power") {
        PowerShell(
            container = container,
            onOpenSettings = onOpenSettings,
            onOpenLaunchpad = onOpenLaunchpad,
            onOpenRuns = onOpenRuns,
            onOpenUsage = onOpenUsage,
            onOpenMemory = onOpenMemory,
            onOpenDevice = onOpenDevice,
            onOpenBrowser = onOpenBrowser,
            initialGoal = initialGoal,
        )
        return
    }

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
            onOpenBrowser = onOpenBrowser,
        )

        else -> ChatRoute(
            container = container,
            activeTab = tab,
            onSelectTab = selectTab,
            initialGoal = initialGoal,
        )
    }
}

@Composable
private fun EasyShell(
    container: AppContainer,
    onOpenSettings: () -> Unit,
    initialGoal: String,
) {
    var tab by rememberSaveable { mutableStateOf("talk") }
    val select: (String) -> Unit = { key ->
        when (key) {
            "settings" -> onOpenSettings()
            "talk", "history" -> tab = key
        }
    }

    if (tab == "history") {
        EasyHistoryRoute(
            container = container,
            active = tab,
            onSelectTab = select,
            onOpen = { id ->
                container.selectedConversation.value = id
                tab = "talk"
            },
        )
    } else {
        ChatRoute(
            container = container,
            activeTab = tab,
            onSelectTab = select,
            initialGoal = initialGoal,
            easy = true,
            onOpenSettings = onOpenSettings,
        )
    }
}

@Composable
private fun PowerShell(
    container: AppContainer,
    onOpenSettings: () -> Unit,
    onOpenLaunchpad: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onOpenMemory: () -> Unit,
    onOpenDevice: () -> Unit,
    onOpenBrowser: () -> Unit,
    initialGoal: String,
) {
    var tab by rememberSaveable { mutableStateOf("chat") }
    var chatStarted by rememberSaveable { mutableStateOf(false) }

    val select: (String) -> Unit = { key ->
        when (key) {
            "chat" -> {
                chatStarted = true
                tab = "chat"
            }

            "activity", "capabilities" -> tab = key
        }
    }

    when {
        tab == "activity" -> ActivityRoute(
            container = container,
            activeTab = tab,
            onSelectTab = select,
            onOpenRuns = onOpenRuns,
            onOpenUsage = onOpenUsage,
        )

        tab == "capabilities" -> CapabilitiesRoute(
            container = container,
            activeTab = tab,
            onSelectTab = select,
            onOpenLaunchpad = onOpenLaunchpad,
            onOpenSettings = onOpenSettings,
            onOpenRuns = onOpenRuns,
            onOpenUsage = onOpenUsage,
            onOpenMemory = onOpenMemory,
            onOpenDevice = onOpenDevice,
            onOpenBrowser = onOpenBrowser,
        )

        chatStarted -> ChatRoute(
            container = container,
            activeTab = tab,
            onSelectTab = select,
            initialGoal = initialGoal,
        )

        else -> PowerHomeRoute(
            container = container,
            active = "chat",
            onSelectTab = select,
            onRun = { goal ->
                container.pendingGoal.value = goal
                chatStarted = true
                tab = "chat"
            },
        )
    }
}
