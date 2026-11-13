package com.hopa.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.hopa.app.di.AppContainer
import com.hopa.app.feature.capabilities.CapabilitiesRoute
import com.hopa.app.feature.chat.ChatRoute
import com.hopa.app.feature.launchpad.LaunchpadRoute
import com.hopa.app.feature.conversations.ConversationsRoute
import com.hopa.app.feature.profiles.ProfilesRoute
import com.hopa.app.feature.runs.RunsRoute
import com.hopa.app.feature.settings.SettingsRoute

@Composable
fun HopaNavHost(container: AppContainer) {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = HopaDestination.CHAT) {
        composable(HopaDestination.CHAT) {
            ChatRoute(
                container = container,
                onOpenConversations = { navController.navigate(HopaDestination.CONVERSATIONS) },
                onOpenSettings = { navController.navigate(HopaDestination.SETTINGS) },
                onOpenActivity = { navController.navigate(HopaDestination.RUNS) },
                onOpenCapabilities = { navController.navigate(HopaDestination.CAPABILITIES) },
            )
        }
        composable(HopaDestination.CONVERSATIONS) {
            ConversationsRoute(
                container = container,
                onBack = { navController.popBackStack() },
            )
        }
        composable(HopaDestination.SETTINGS) {
            SettingsRoute(
                container = container,
                onBack = { navController.popBackStack() },
                onOpenCapabilities = { navController.navigate(HopaDestination.CAPABILITIES) },
                onOpenLaunchpad = { navController.navigate(HopaDestination.LAUNCHPAD) },
                onOpenProfiles = { navController.navigate(HopaDestination.PROFILES) },
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
        composable(HopaDestination.CAPABILITIES) {
            CapabilitiesRoute(
                container = container,
                onBack = { navController.popBackStack() },
                onOpenLaunchpad = { navController.navigate(HopaDestination.LAUNCHPAD) },
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
