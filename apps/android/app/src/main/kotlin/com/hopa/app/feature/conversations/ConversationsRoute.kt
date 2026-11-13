package com.hopa.app.feature.conversations

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.hopa.app.di.AppContainer
import com.hopa.data.sessions.Conversation
import kotlinx.coroutines.launch

@Composable
fun ConversationsRoute(
    container: AppContainer,
    onBack: () -> Unit,
) {
    var conversations by remember { mutableStateOf<List<Conversation>>(emptyList()) }
    var refresh by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(refresh) {
        conversations = container.conversations.all()
    }

    ConversationsScreen(
        conversations = conversations,
        onBack = onBack,
        onSelect = { id ->
            container.selectedConversation.value = id
            onBack()
        },
        onDelete = { id ->
            scope.launch {
                container.conversations.delete(id)
                refresh += 1
            }
        },
        onNewChat = {
            scope.launch {
                val created = container.conversations.create()
                container.selectedConversation.value = created.id
                onBack()
            }
        },
    )
}
