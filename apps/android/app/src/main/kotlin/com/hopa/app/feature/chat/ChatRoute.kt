package com.hopa.app.feature.chat

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hopa.app.di.AppContainer
import com.hopa.app.feature.conversations.ChatsSheet

@Composable
fun ChatRoute(
    container: AppContainer,
    onOpenActivity: () -> Unit,
    onOpenCapabilities: () -> Unit,
) {
    val viewModel: ChatViewModel = viewModel(factory = ChatViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    var chatsOpen by remember { mutableStateOf(false) }

    ChatScreen(
        state = state,
        onInput = viewModel::onInput,
        onSend = viewModel::send,
        onOption = viewModel::sendOption,
        onQuick = viewModel::sendQuick,
        onApprove = viewModel::resolveApproval,
        onNewChat = viewModel::newChat,
        onOpenConversations = { chatsOpen = true },
        onOpenActivity = onOpenActivity,
        onOpenCapabilities = onOpenCapabilities,
    )

    if (chatsOpen) {
        ChatsSheet(
            container = container,
            currentId = state.current?.id,
            onDismiss = { chatsOpen = false },
            onSelect = { id ->
                viewModel.select(id)
                chatsOpen = false
            },
            onNewChat = { chatsOpen = false },
        )
    }
}
