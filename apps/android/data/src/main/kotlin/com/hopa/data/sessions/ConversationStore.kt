package com.hopa.data.sessions

interface ConversationStore {
    suspend fun all(): List<Conversation>

    suspend fun create(): Conversation

    suspend fun append(id: String, message: ChatMessage)

    suspend fun rename(id: String, title: String)

    suspend fun delete(id: String)
}
