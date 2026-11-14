package com.hopa.app.feature.power

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.core.contracts.RunRecord

@Composable
fun PowerHomeRoute(
    container: AppContainer,
    active: String,
    onSelectTab: (String) -> Unit,
    onRun: (String) -> Unit,
) {
    var recent by remember { mutableStateOf<List<RunRecord>>(emptyList()) }
    LaunchedEffect(Unit) {
        recent = container.recorder.all()
    }
    PowerHomeScreen(
        recent = recent,
        active = active,
        onSelectTab = onSelectTab,
        onRun = onRun,
    )
}
