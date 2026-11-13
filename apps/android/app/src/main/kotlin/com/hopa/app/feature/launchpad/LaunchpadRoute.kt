package com.hopa.app.feature.launchpad

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.core.ports.InstalledApp
import kotlinx.coroutines.launch

@Composable
fun LaunchpadRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    var apps by remember { mutableStateOf<List<InstalledApp>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        apps = runCatching { container.packages.installed() }
            .getOrElse {
                error = it.message
                emptyList()
            }
    }

    LaunchpadScreen(
        apps = apps,
        error = error,
        onBack = onBack,
        onLaunch = { packageName ->
            scope.launch {
                runCatching { container.packages.launch(packageName) }
                    .onFailure { error = it.message }
            }
        },
    )
}
