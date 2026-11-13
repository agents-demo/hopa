package com.hopa.app.feature.activity

import android.content.Intent
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.platform.LocalContext
import com.hopa.app.di.AppContainer

@Composable
fun ActivityRoute(
    container: AppContainer,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onOpenRuns: () -> Unit,
) {
    val viewModel: ActivityViewModel = viewModel(factory = ActivityViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    ActivityScreen(
        state = state,
        activeTab = activeTab,
        onSelectTab = onSelectTab,
        onOpenRuns = onOpenRuns,
        onShare = {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, viewModel.shareText())
            }
            context.startActivity(Intent.createChooser(send, "Share week"))
        },
        onUnavailable = { feature ->
            Toast.makeText(
                context,
                "$feature is not on Android yet.",
                Toast.LENGTH_SHORT,
            ).show()
        },
    )
}
