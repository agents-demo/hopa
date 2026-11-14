package com.hopa.app.feature.memory

import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer

@Composable
fun MemoryRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    val viewModel: MemoryViewModel = viewModel(factory = MemoryViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    MemoryScreen(
        state = state,
        onBack = onBack,
        onAddFact = viewModel::addFact,
        onDeleteFact = viewModel::deleteFact,
        onAddSkill = viewModel::addSkill,
        onDeleteSkill = viewModel::deleteSkill,
        onClearAll = viewModel::clearAll,
        onExport = {
            val text = buildString {
                appendLine("HOPA memory")
                state.facts.forEach { appendLine("- $it") }
                appendLine()
                appendLine("HOPA skills")
                state.skills.forEach { appendLine("- \"${it.trigger}\" → ${it.action}") }
            }
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            context.startActivity(Intent.createChooser(send, "Export memory"))
        },
    )
}
