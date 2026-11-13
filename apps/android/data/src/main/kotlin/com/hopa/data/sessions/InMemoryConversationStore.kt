package com.hopa.data.sessions

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class InMemoryConversationStore : ConversationStore {
    private val mutex = Mutex()
    private val conversations = mutableListOf<Conversation>()
    private var counter = 0

    override suspend fun all(): List<Conversation> = mutex.withLock {
        conversations.filter { it.archivedAt == 0L }
            .sortedWith(compareByDescending<Conversation> { it.pinned }.thenByDescending { it.updatedAt })
    }

    override suspend fun search(query: String): List<Conversation> = mutex.withLock {
        val needle = query.trim()
        if (needle.isEmpty()) {
            conversations.filter { it.archivedAt == 0L }
        } else {
            conversations.filter { conversation ->
                conversation.archivedAt == 0L &&
                    (conversation.title.contains(needle, ignoreCase = true) ||
                        conversation.messages.any { it.text.contains(needle, ignoreCase = true) })
            }
        }
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

    override suspend fun deleteAll() = mutex.withLock {
        conversations.clear()
    }

    override suspend fun restore(id: String) = Unit

    override suspend fun setPinned(id: String, pinned: Boolean) = mutex.withLock {
        val index = conversations.indexOfFirst { it.id == id }
        if (index >= 0) {
            conversations[index] = conversations[index].copy(pinned = pinned)
        }
    }

    override suspend fun archive(id: String) = mutex.withLock {
        val index = conversations.indexOfFirst { it.id == id }
        if (index >= 0) {
            conversations[index] = conversations[index].copy(archivedAt = System.currentTimeMillis())
        }
    }
}
