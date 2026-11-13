package com.hopa.app.feature.runs

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.core.contracts.RunRecord

@Composable
fun RunsRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    var records by remember { mutableStateOf<List<RunRecord>>(emptyList()) }
    LaunchedEffect(Unit) {
        records = container.recorder.all()
    }
    RunsScreen(records = records, onBack = onBack)
}
