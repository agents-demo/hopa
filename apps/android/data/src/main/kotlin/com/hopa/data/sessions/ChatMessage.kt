package com.hopa.data.sessions

data class ChatMessage(
    val id: String,
    val role: String,
    val text: String,
    val timestamp: Long,
)
