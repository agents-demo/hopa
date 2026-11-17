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
import com.hopa.stores.AppSettings

@Composable
fun ChatRoute(
    container: AppContainer,
    activeTab: String,
    onSelectTab: (String) -> Unit,
    onOpenActMode: () -> Unit = {},
    initialGoal: String = "",
    easy: Boolean = false,
    onOpenSettings: () -> Unit = {},
) {
    val viewModel: ChatViewModel = viewModel(factory = ChatViewModelFactory(container))
    val state by viewModel.state.collectAsStateWithLifecycle()
    val settings by container.settings.settings.collectAsStateWithLifecycle(
        initialValue = AppSettings(),
    )
    val tasks by container.runner.tasks.collectAsStateWithLifecycle()
    var chatsOpen by remember { mutableStateOf(false) }

    androidx.compose.runtime.LaunchedEffect(Unit) {
        for (goal in container.pendingGoals) {
            viewModel.prefill(goal)
            // send() marks the app busy before it returns, so the next queued
            // goal is routed to the parallel runner instead of replacing this one.
            viewModel.send()
        }
    }

    androidx.compose.runtime.LaunchedEffect(initialGoal) {
        if (initialGoal.isNotBlank()) {
            viewModel.prefill(initialGoal)
        }
    }

    ChatScreen(
        state = state,
        activeTab = activeTab,
        onSelectTab = onSelectTab,
        onOpenActMode = onOpenActMode,
        onInput = viewModel::onInput,
        onSend = viewModel::send,
        onOption = viewModel::sendOption,
        onQuick = viewModel::sendQuick,
        onNewChat = viewModel::newChat,
        onOpenConversations = { chatsOpen = true },
        onStartVoice = viewModel::startVoice,
        onStopVoice = viewModel::stopVoice,
        onDismissVoiceError = viewModel::dismissVoiceError,
        onSpeak = viewModel::speak,
        onRetry = viewModel::retryLast,
        onUndo = viewModel::undoLast,
        onDiscardAttachment = viewModel::discardAttachment,
        onDismissAttachmentNotice = viewModel::dismissAttachmentNotice,
        easy = easy,
        onOpenSettings = onOpenSettings,
        accessAllowed = settings.accessibilityAllowed,
        onApprovePlan = viewModel::approvePlan,
        onCancelPlan = viewModel::cancelPlan,
        onSaveSkill = viewModel::saveSkill,
        tasks = tasks,
        onOpenTask = { viewModel.select(it.conversationId) },
        onDismissTask = { container.runner.dismiss(it) },
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
