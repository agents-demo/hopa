package com.hopa.app.feature.profiles

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@Composable
fun ProfilesRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    var selected by remember { mutableStateOf("everyday") }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        selected = container.settings.settings.first().profile
    }

    ProfilesScreen(
        selected = selected,
        onBack = onBack,
        onSelect = { profile ->
            selected = profile
            scope.launch {
                container.settings.update { it.copy(profile = profile) }
                onBack()
            }
        },
    )
}
