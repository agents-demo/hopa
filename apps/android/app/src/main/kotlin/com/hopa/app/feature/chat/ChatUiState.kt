package com.hopa.app.feature.chat

import com.hopa.core.gate.ApprovalRequest
import com.hopa.data.sessions.Conversation

data class ChatUiState(
    val conversations: List<Conversation> = emptyList(),
    val current: Conversation? = null,
    val input: String = "",
    val busy: Boolean = false,
    val error: String? = null,
    val options: List<String> = emptyList(),
    val pendingApproval: ApprovalRequest? = null,
)
