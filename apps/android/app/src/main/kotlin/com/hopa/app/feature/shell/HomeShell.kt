package com.hopa.app.feature.shell

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hopa.app.di.AppContainer
import com.hopa.feature.history.ActivityRoute
import com.hopa.feature.capabilities.CapabilitiesRoute
import com.hopa.app.feature.chat.ChatRoute
import com.hopa.feature.easy.EasyHistoryRoute
import com.hopa.feature.power.PowerHomeRoute
import com.hopa.stores.AppSettings
import com.hopa.ui.theme.HopaColor

/**
 * The three top-level pages from Index.ets. The tab state lives here, not in
 * the navigation graph, so switching tabs never stacks a back entry.
 *
 * The Easy profile gets its own bar (Talk / History / Settings), as on Harmony.
 *
 * [banner] is an optional one-line notice (for example, "the gateway is
 * unreachable") overlaid across the top of the shell.
 */
@Composable
fun HomeShell(
    container: AppContainer,
    onOpenSettings: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onOpenHistory: () -> Unit = {},
    onOpenRecipes: () -> Unit = {},
    onOpenMemory: () -> Unit,
    onOpenSkills: () -> Unit = onOpenMemory,
    onOpenRunningApps: () -> Unit,
    onOpenActMode: () -> Unit,
    onOpenBrowser: () -> Unit,
    onOpenAccount: () -> Unit,
    initialGoal: String = "",
    banner: String? = null,
) {
    val settings by container.settings.settings.collectAsStateWithLifecycle(
        initialValue = AppSettings(),
    )
    val shared by container.pendingAttachment.collectAsStateWithLifecycle()
    val sharedNotice by container.pendingNotice.collectAsStateWithLifecycle()
    val incoming = shared != null || sharedNotice != null
    val accountTitle = if (settings.backendDeviceId.isNotBlank()) "Signed in" else "Sign in"
    val accountHint = when {
        settings.backendDeviceId.isNotBlank() -> "Connected to your computer"
        settings.accountSkipped -> "This phone only — tap to connect"
        else -> "Connect this phone with your computer"
    }
    if (settings.profile == "easy") {
        EasyShell(
            container = container,
            onOpenSettings = onOpenSettings,
            onOpenActMode = onOpenActMode,
            initialGoal = initialGoal,
            shared = incoming,
            banner = banner,
        )
        return
    }
    if (settings.profile == "power") {
        PowerShell(
            container = container,
            onOpenSettings = onOpenSettings,
            onOpenRuns = onOpenRuns,
            onOpenUsage = onOpenUsage,
            onOpenHistory = onOpenHistory,
            onOpenRecipes = onOpenRecipes,
            onOpenMemory = onOpenMemory,
            onOpenSkills = onOpenSkills,
            onOpenRunningApps = onOpenRunningApps,
            onOpenActMode = onOpenActMode,
            onOpenBrowser = onOpenBrowser,
            onOpenAccount = onOpenAccount,
            accountTitle = accountTitle,
            accountHint = accountHint,
            initialGoal = initialGoal,
            shared = incoming,
            banner = banner,
        )
        return
    }

    var tab by rememberSaveable { mutableStateOf("chat") }
    androidx.compose.runtime.LaunchedEffect(shared, sharedNotice) {
        if (shared != null || sharedNotice != null) {
            tab = "chat"
        }
    }
    val selectTab: (String) -> Unit = { key ->
        if (key == "chat" || key == "activity" || key == "capabilities") {
            tab = key
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        when (tab) {
            "activity" -> ActivityRoute(
                activeTab = tab,
                onSelectTab = selectTab,
                onOpenRuns = onOpenRuns,
                onOpenUsage = onOpenUsage,
                onOpenHistory = onOpenHistory,
                onOpenRecipes = onOpenRecipes,
            )

            "capabilities" -> CapabilitiesRoute(
                activeTab = tab,
                onSelectTab = selectTab,
                onOpenSettings = onOpenSettings,
                onOpenRuns = onOpenRuns,
                onOpenMemory = onOpenMemory,
                onOpenSkills = onOpenSkills,
                onOpenRunningApps = onOpenRunningApps,
                onOpenBrowser = onOpenBrowser,
                accountTitle = accountTitle,
                accountHint = accountHint,
                onOpenAccount = onOpenAccount,
            )

            else -> ChatRoute(
                activeTab = tab,
                onSelectTab = selectTab,
                onOpenActMode = onOpenActMode,
                initialGoal = initialGoal,
            )
        }
        banner?.let { text ->
            AccountBanner(text, modifier = Modifier.align(Alignment.TopCenter))
        }
    }
}

@Composable
private fun EasyShell(
    container: AppContainer,
    onOpenSettings: () -> Unit,
    onOpenActMode: () -> Unit,
    initialGoal: String,
    shared: Boolean,
    banner: String?,
) {
    var tab by rememberSaveable { mutableStateOf("talk") }
    androidx.compose.runtime.LaunchedEffect(shared) {
        if (shared) {
            tab = "talk"
        }
    }
    val select: (String) -> Unit = { key ->
        when (key) {
            "settings" -> onOpenSettings()
            "talk", "history" -> tab = key
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        if (tab == "history") {
            EasyHistoryRoute(
                active = tab,
                onSelectTab = select,
                onOpen = { id ->
                    container.selectedConversation.value = id
                    tab = "talk"
                },
            )
        } else {
            ChatRoute(
                activeTab = tab,
                onSelectTab = select,
                onOpenActMode = onOpenActMode,
                initialGoal = initialGoal,
                easy = true,
                onOpenSettings = onOpenSettings,
            )
        }
        banner?.let { text ->
            AccountBanner(text, modifier = Modifier.align(Alignment.TopCenter))
        }
    }
}

@Composable
private fun PowerShell(
    container: AppContainer,
    onOpenSettings: () -> Unit,
    onOpenRuns: () -> Unit,
    onOpenUsage: () -> Unit,
    onOpenHistory: () -> Unit = {},
    onOpenRecipes: () -> Unit = {},
    onOpenMemory: () -> Unit,
    onOpenSkills: () -> Unit,
    onOpenRunningApps: () -> Unit,
    onOpenActMode: () -> Unit,
    onOpenBrowser: () -> Unit,
    onOpenAccount: () -> Unit,
    accountTitle: String,
    accountHint: String,
    initialGoal: String,
    shared: Boolean,
    banner: String?,
) {
    var tab by rememberSaveable { mutableStateOf("chat") }
    var chatStarted by rememberSaveable { mutableStateOf(false) }
    androidx.compose.runtime.LaunchedEffect(shared) {
        if (shared) {
            chatStarted = true
            tab = "chat"
        }
    }

    val select: (String) -> Unit = { key ->
        when (key) {
            "chat" -> {
                chatStarted = true
                tab = "chat"
            }

            "activity", "capabilities" -> tab = key
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            tab == "activity" -> ActivityRoute(
                activeTab = tab,
                onSelectTab = select,
                onOpenRuns = onOpenRuns,
                onOpenUsage = onOpenUsage,
                onOpenHistory = onOpenHistory,
                onOpenRecipes = onOpenRecipes,
            )

            tab == "capabilities" -> CapabilitiesRoute(
                activeTab = tab,
                onSelectTab = select,
                onOpenSettings = onOpenSettings,
                onOpenRuns = onOpenRuns,
                onOpenMemory = onOpenMemory,
                onOpenSkills = onOpenSkills,
                onOpenRunningApps = onOpenRunningApps,
                onOpenBrowser = onOpenBrowser,
                accountTitle = accountTitle,
                accountHint = accountHint,
                onOpenAccount = onOpenAccount,
            )

            chatStarted -> ChatRoute(
                activeTab = tab,
                onSelectTab = select,
                onOpenActMode = onOpenActMode,
                initialGoal = initialGoal,
            )

            else -> PowerHomeRoute(
                active = "chat",
                onSelectTab = select,
                onRun = { goal ->
                    container.pendingGoals.trySend(goal)
                    chatStarted = true
                    tab = "chat"
                },
            )
        }
        banner?.let { text ->
            AccountBanner(text, modifier = Modifier.align(Alignment.TopCenter))
        }
    }
}

/** A one-line notice across the top, drawn over whatever tab is showing. */
@Composable
private fun AccountBanner(text: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier
            .statusBarsPadding()
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        shape = RoundedCornerShape(16.dp),
        color = HopaColor.Surface,
        border = BorderStroke(1.dp, HopaColor.Divider),
        shadowElevation = 2.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(HopaColor.Warning, CircleShape),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Account offline",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = HopaColor.TextPrimary,
                )
                Text(
                    text,
                    fontSize = 10.5.sp,
                    color = HopaColor.TextSecondary,
                )
            }
        }
    }
}
