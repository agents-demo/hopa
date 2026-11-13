package com.hopa.app.feature.conversations

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer
import com.hopa.data.sessions.Conversation

@Composable
fun ConversationsRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    val viewModel: ConversationsViewModel = viewModel(
        factory = ConversationsViewModelFactory(container),
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    ConversationsScreen(
        state = state,
        onBack = onBack,
        onQuery = viewModel::onQuery,
        onSelect = { id ->
            viewModel.select(id)
            onBack()
        },
        onNewChat = {
            viewModel.newChat { onBack() }
        },
        onRename = viewModel::rename,
        onDelete = viewModel::delete,
        onUndoDelete = viewModel::undoDelete,
        onTogglePin = { conversation: Conversation, pinned: Boolean ->
            viewModel.setPinned(conversation, pinned)
        },
        onArchive = viewModel::archive,
        onDeleteAll = viewModel::deleteAll,
    )
}
