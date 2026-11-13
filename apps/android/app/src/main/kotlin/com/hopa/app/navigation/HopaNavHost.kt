package com.hopa.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.hopa.app.di.AppContainer
import com.hopa.app.feature.launchpad.LaunchpadRoute
import com.hopa.app.feature.memory.MemoryRoute
import com.hopa.app.feature.profiles.ProfilesRoute
import com.hopa.app.feature.runs.RunsRoute
import com.hopa.app.feature.settings.AccessibilityRoute
import com.hopa.app.feature.settings.SettingsRoute
import com.hopa.app.feature.usage.UsageRoute
import com.hopa.app.feature.shell.HomeShell

@Composable
fun HopaNavHost(container: AppContainer, initialGoal: String = "") {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = HopaDestination.CHAT) {
        composable(HopaDestination.CHAT) {
            HomeShell(
                container = container,
                onOpenSettings = { navController.navigate(HopaDestination.SETTINGS) },
                onOpenLaunchpad = { navController.navigate(HopaDestination.LAUNCHPAD) },
                onOpenRuns = { navController.navigate(HopaDestination.RUNS) },
                onOpenUsage = { navController.navigate(HopaDestination.USAGE) },
                onOpenMemory = { navController.navigate(HopaDestination.MEMORY) },
                initialGoal = initialGoal,
            )
        }
        composable(HopaDestination.USAGE) {
            UsageRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
        composable(HopaDestination.MEMORY) {
            MemoryRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
        composable(HopaDestination.SETTINGS) {
            SettingsRoute(
                container = container,
                onBack = { navController.popBackStack() },
                onOpenCapabilities = { navController.popBackStack() },
                onOpenLaunchpad = { navController.navigate(HopaDestination.LAUNCHPAD) },
                onOpenProfiles = { navController.navigate(HopaDestination.PROFILES) },
                onOpenAccessibility = { navController.navigate(HopaDestination.ACCESSIBILITY) },
            )
        }
        composable(HopaDestination.ACCESSIBILITY) {
            AccessibilityRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
        composable(HopaDestination.PROFILES) {
            ProfilesRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
        composable(HopaDestination.RUNS) {
            RunsRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
        composable(HopaDestination.LAUNCHPAD) {
            LaunchpadRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
    }
}
