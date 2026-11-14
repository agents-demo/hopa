package com.hopa.app.feature.conversations

import com.hopa.data.sessions.Conversation

data class ConversationsUiState(
    val conversations: List<Conversation> = emptyList(),
    val query: String = "",
    val loading: Boolean = true,
    val error: String? = null,
)
