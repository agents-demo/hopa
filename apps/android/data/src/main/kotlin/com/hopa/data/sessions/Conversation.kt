package com.hopa.data.sessions

data class Conversation(
    val id: String,
    val title: String,
    val messages: List<ChatMessage> = emptyList(),
    val updatedAt: Long = 0,
    val deletedAt: Long = 0,
    val pinned: Boolean = false,
    val archivedAt: Long = 0,
)
