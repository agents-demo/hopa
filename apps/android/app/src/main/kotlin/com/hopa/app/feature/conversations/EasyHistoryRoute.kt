package com.hopa.app.feature.conversations

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.data.sessions.Conversation

@Composable
fun EasyHistoryRoute(
    container: AppContainer,
    active: String,
    onSelectTab: (String) -> Unit,
    onOpen: (String) -> Unit,
) {
    var conversations by remember { mutableStateOf<List<Conversation>>(emptyList()) }
    LaunchedEffect(Unit) {
        conversations = container.conversations.all()
            .filter { it.messages.isNotEmpty() }
    }

    EasyHistoryScreen(
        conversations = conversations,
        active = active,
        onSelectTab = onSelectTab,
        onOpen = onOpen,
    )
}
