package com.hopa.app.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import com.hopa.app.BuildConfig
import com.hopa.app.account.SignInRoute
import com.hopa.app.di.AppContainer
import com.hopa.app.pair.ScanRoute
import com.hopa.backend.pairing.AccountClient
import com.hopa.ui.component.HopaMascot
import com.hopa.ui.theme.HopaColor
import com.hopa.feature.browser.BrowserRoute
import com.hopa.feature.execution.ComputerRoute
import com.hopa.app.feature.execution.DecisionsRoute
import com.hopa.feature.execution.HowHopaActsRoute
import com.hopa.feature.execution.RunPrefsRoute
import com.hopa.feature.execution.RunSetupRoute
import com.hopa.feature.execution.RunningAppsRoute
import com.hopa.feature.history.HistoryRoute
import com.hopa.feature.history.RecipesRoute
import com.hopa.feature.launchpad.AppCardRoute
import com.hopa.feature.launchpad.LaunchpadRoute
import com.hopa.feature.memory.MemoryRoute
import com.hopa.feature.profiles.ProfilesRoute
import com.hopa.feature.runs.RunsRoute
import com.hopa.app.feature.settings.AboutScreen
import com.hopa.app.feature.settings.AccessibilityRoute
import com.hopa.app.feature.settings.AnswersRoute
import com.hopa.app.feature.settings.SelfCheckRoute
import com.hopa.app.feature.settings.SettingsRoute
import com.hopa.app.feature.shell.HomeShell
import com.hopa.feature.skills.SkillsRoute
import com.hopa.feature.usage.UsageRoute

/** The launch decision plus the resolved gateway URL it was computed from. */
private data class ResolvedLaunch(
    val decision: LaunchDecision,
    val gatewayUrl: String,
)

@Composable
fun HopaNavHost(container: AppContainer, initialGoal: String = "") {
    val navController = rememberNavController()
    val launch by produceState<ResolvedLaunch?>(initialValue = null) {
        var lastUrl: String? = null
        var lastDeviceId: String? = null
        var lastSkipped: Boolean? = null
        container.settings.settings.collect { current ->
            // Re-decide only when the gateway, identity or skip choice changes;
            // every other settings emission (mascot, model, …) must not re-run
            // the probe.
            if (value != null && current.backendUrl == lastUrl &&
                current.backendDeviceId == lastDeviceId &&
                current.accountSkipped == lastSkipped
            ) {
                return@collect
            }
            lastUrl = current.backendUrl
            lastDeviceId = current.backendDeviceId
            lastSkipped = current.accountSkipped
            val url = BuildConfig.BACKEND_URL?.takeIf { it.isNotBlank() } ?: current.backendUrl
            value = ResolvedLaunch(
                decision = resolveLaunch(
                    configuredUrl = BuildConfig.BACKEND_URL,
                    storedUrl = current.backendUrl,
                    storedDeviceId = current.backendDeviceId,
                    health = { gateway -> AccountClient(gateway).health() },
                    skipped = current.accountSkipped,
                ),
                gatewayUrl = url,
            )
        }
    }
    val resolved = launch
    if (resolved == null) {
        LaunchLoading()
        return
    }
    val startDestination = if (resolved.decision.mode == LaunchMode.SignIn) {
        HopaDestination.SignIn
    } else {
        HopaDestination.Chat
    }
    NavHost(navController = navController, startDestination = startDestination) {
        composable<HopaDestination.Chat> {
            HomeShell(
                container = container,
                onOpenSettings = { navController.navigate(HopaDestination.Settings) },
                onOpenRuns = { navController.navigate(HopaDestination.Runs) },
                onOpenUsage = { navController.navigate(HopaDestination.Usage) },
                onOpenHistory = { navController.navigate(HopaDestination.History) },
                onOpenRecipes = { navController.navigate(HopaDestination.Recipes) },
                onOpenMemory = { navController.navigate(HopaDestination.Memory) },
                onOpenSkills = { navController.navigate(HopaDestination.Skills) },
                onOpenRunningApps = { navController.navigate(HopaDestination.RunningApps) },
                onOpenActMode = { navController.navigate(HopaDestination.ActMode) },
                onOpenBrowser = { navController.navigate(HopaDestination.Browser()) },
                onOpenAccount = { navController.navigate(HopaDestination.SignIn) },
                initialGoal = initialGoal,
                banner = resolved.decision.banner,
            )
        }
        composable<HopaDestination.SignIn> {
            SignInRoute(
                container = container,
                gatewayUrl = resolved.gatewayUrl,
                onSignedIn = {
                    navController.navigate(HopaDestination.Chat) {
                        popUpTo(HopaDestination.SignIn) { inclusive = true }
                    }
                },
                onBack = if (navController.previousBackStackEntry != null) {
                    { navController.popBackStack() }
                } else {
                    null
                },
            )
        }
        composable<HopaDestination.Usage> {
            UsageRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.History> {
            HistoryRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Recipes> {
            RecipesRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Memory> {
            MemoryRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Skills> {
            SkillsRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Browser> { entry ->
            BrowserRoute(
                initialUrl = entry.toRoute<HopaDestination.Browser>().url,
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Settings> {
            SettingsRoute(
                onBack = { navController.popBackStack() },
                onOpenProfiles = { navController.navigate(HopaDestination.Profiles) },
                onOpenSelfCheck = { navController.navigate(HopaDestination.SelfCheck) },
                onOpenAbout = { navController.navigate(HopaDestination.About) },
            )
        }
        composable<HopaDestination.RunningApps> {
            RunningAppsRoute(
                onBack = { navController.popBackStack() },
                onOpenHowHopaActs = { navController.navigate(HopaDestination.ActMode) },
                onOpenAllApps = { navController.navigate(HopaDestination.Launchpad("apps")) },
                onOpenSites = { navController.navigate(HopaDestination.Launchpad("sites")) },
                onOpenSetup = { navController.navigate(HopaDestination.RunSetup) },
                onOpenRunPrefs = { navController.navigate(HopaDestination.RunPrefs) },
            )
        }
        composable<HopaDestination.ActMode> {
            HowHopaActsRoute(
                container = container,
                onBack = { navController.popBackStack() },
                onOpenScreenAccess = { navController.navigate(HopaDestination.Accessibility) },
                onOpenComputer = { navController.navigate(HopaDestination.Computer) },
                onOpenSetup = { navController.navigate(HopaDestination.RunSetup) },
                onOpenDecisions = { navController.navigate(HopaDestination.Decisions) },
                onOpenAnswers = { navController.navigate(HopaDestination.Answers) },
            )
        }
        composable<HopaDestination.Answers> {
            AnswersRoute(onBack = { navController.popBackStack() })
        }
        composable<HopaDestination.Decisions> {
            DecisionsRoute(onBack = { navController.popBackStack() })
        }
        composable<HopaDestination.RunSetup> {
            RunSetupRoute(
                container = container,
                onBack = { navController.popBackStack() },
                onOpenScreenAccess = { navController.navigate(HopaDestination.Accessibility) },
                onOpenComputer = { navController.navigate(HopaDestination.Computer) },
            )
        }
        composable<HopaDestination.RunPrefs> {
            RunPrefsRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Computer> {
            ComputerRoute(
                onBack = { navController.popBackStack() },
                showGatewayPairing = resolved.decision.showGatewayPairing,
                onScanPc = { navController.navigate(HopaDestination.Scan) },
            )
        }
        composable<HopaDestination.Scan> {
            ScanRoute(
                container = container,
                onBack = { navController.popBackStack() },
                onVouched = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.SelfCheck> {
            SelfCheckRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.About> {
            AboutScreen(onBack = { navController.popBackStack() })
        }
        composable<HopaDestination.Accessibility> {
            AccessibilityRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Profiles> {
            ProfilesRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Runs> {
            RunsRoute(
                onBack = { navController.popBackStack() },
            )
        }
        composable<HopaDestination.Launchpad> { entry ->
            LaunchpadRoute(
                onBack = { navController.popBackStack() },
                section = entry.toRoute<HopaDestination.Launchpad>().section,
                onOpenApp = { name ->
                    navController.navigate(HopaDestination.AppCard(name))
                },
                onOpenSite = { url ->
                    navController.navigate(HopaDestination.Browser(url))
                },
            )
        }
        composable<HopaDestination.AppCard> { entry ->
            AppCardRoute(
                name = entry.toRoute<HopaDestination.AppCard>().name,
                onBack = { navController.popBackStack() },
                onOpenScreenAccess = { navController.navigate(HopaDestination.Accessibility) },
            )
        }
    }

    LaunchedEffect(Unit) {
        if (!StartedDestination.checked) {
            StartedDestination.checked = true
            val atHome = navController.currentBackStackEntry
                ?.destination
                ?.let { destination ->
                    destination.hasRoute<HopaDestination.Chat>() ||
                        destination.hasRoute<HopaDestination.SignIn>()
                } == true
            if (!atHome) {
                // A cold start must not restore a settings page with no back
                // entry; open the home instead.
                navController.navigate(startDestination) {
                    popUpTo(0) { inclusive = true }
                }
            }
        }
    }
}

/** Process-scoped: rotation keeps the person where they were. */
private object StartedDestination {
    var checked = false
}

/** Shown while the launch probe runs, instead of a blank frame. */
@Composable
private fun LaunchLoading() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(HopaColor.Bg),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            HopaMascot(sizeDp = 104.dp)
            Text("Waking up…", fontSize = 13.sp, color = HopaColor.TextHint)
        }
    }
}
