package com.hopa.app.feature.chat

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer

@Composable
fun ChatRoute(
    container: AppContainer,
    onOpenConversations: () -> Unit,
    onOpenActivity: () -> Unit,
    onOpenCapabilities: () -> Unit,
) {
    val viewModel: ChatViewModel = viewModel(factory = ChatViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    ChatScreen(
        state = state,
        onInput = viewModel::onInput,
        onSend = viewModel::send,
        onOption = viewModel::sendOption,
        onQuick = viewModel::sendQuick,
        onApprove = viewModel::resolveApproval,
        onNewChat = viewModel::newChat,
        onOpenConversations = onOpenConversations,
        onOpenActivity = onOpenActivity,
        onOpenCapabilities = onOpenCapabilities,
    )
}
