package com.hopa.data.sessions

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class InMemoryConversationStore : ConversationStore {
    private val mutex = Mutex()
    private val conversations = mutableListOf<Conversation>()
    private var counter = 0

    override suspend fun all(): List<Conversation> = mutex.withLock {
        conversations.sortedByDescending { it.updatedAt }
    }

    override suspend fun create(): Conversation = mutex.withLock {
        counter += 1
        val now = System.currentTimeMillis()
        val conversation = Conversation(
            id = "c-$now-$counter",
            title = "New chat",
            updatedAt = now,
        )
        conversations += conversation
        conversation
    }

    override suspend fun append(id: String, message: ChatMessage) = mutex.withLock {
        val index = conversations.indexOfFirst { it.id == id }
        if (index < 0) {
            return@withLock
        }
        val old = conversations[index]
        val title = if (old.title == "New chat" && message.role == "user") {
            message.text.take(40)
        } else {
            old.title
        }
        conversations[index] = old.copy(
            title = title,
            messages = old.messages + message,
            updatedAt = message.timestamp,
        )
    }

    override suspend fun rename(id: String, title: String) = mutex.withLock {
        val index = conversations.indexOfFirst { it.id == id }
        if (index >= 0) {
            conversations[index] = conversations[index].copy(title = title)
        }
    }

    override suspend fun delete(id: String) {
        mutex.withLock {
            conversations.removeAll { it.id == id }
        }
    }
}
