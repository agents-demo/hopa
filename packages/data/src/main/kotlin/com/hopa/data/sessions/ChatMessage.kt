package com.hopa.data.sessions

import kotlinx.serialization.Serializable

@Serializable
data class ChatMessage(
    val id: String,
    val role: String,
    val text: String,
    val timestamp: Long,
    val attachment: Attachment? = null,
)
