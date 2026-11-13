package com.hopa.data.sessions

import java.util.UUID

class InMemoryConversationStore : ConversationStore {
    private val rows = linkedMapOf<String, Conversation>()
    private var counter = 0

    override suspend fun all(): List<Conversation> =
        rows.values.filter { it.deletedAt == 0L && it.archivedAt == 0L }
            .sortedWith(compareByDescending<Conversation> { it.pinned }.thenByDescending { it.updatedAt })

    override suspend fun allWithDeleted(): List<Conversation> =
        rows.values.sortedByDescending { it.updatedAt }

    override suspend fun adopt(session: Conversation) {
        val existing = rows[session.id]
        rows[session.id] = if (existing == null) {
            session
        } else {
            existing.copy(
                title = session.title.ifBlank { existing.title },
                updatedAt = maxOf(existing.updatedAt, session.updatedAt),
                deletedAt = maxOf(existing.deletedAt, session.deletedAt),
                pinned = existing.pinned || session.pinned,
                archivedAt = maxOf(existing.archivedAt, session.archivedAt),
                messages = (existing.messages + session.messages).distinctBy { it.id }
                    .sortedBy { it.timestamp },
            )
        }
    }

    override suspend fun search(query: String): List<Conversation> {
        val needle = query.trim()
        if (needle.isEmpty()) {
            return all()
        }
        return all().filter { session ->
            session.title.contains(needle, ignoreCase = true) ||
                session.messages.any { it.text.contains(needle, ignoreCase = true) }
        }
    }

    override suspend fun create(): Conversation {
        val id = "c-${++counter}-${UUID.randomUUID().toString().take(6)}"
        val now = System.currentTimeMillis()
        val session = Conversation(id = id, title = "New chat", updatedAt = now)
        rows[id] = session
        return session
    }

    override suspend fun append(id: String, message: ChatMessage) {
        val session = rows[id] ?: return
        if (session.messages.any { it.id == message.id }) {
            return
        }
        rows[id] = session.copy(
            title = if (session.title == "New chat" && message.role == "user") {
                message.text.take(40)
            } else {
                session.title
            },
            messages = session.messages + message,
            updatedAt = message.timestamp,
        )
    }

    override suspend fun rename(id: String, title: String) {
        rows[id]?.let { rows[id] = it.copy(title = title) }
    }

    override suspend fun delete(id: String) {
        rows[id]?.let { rows[id] = it.copy(deletedAt = System.currentTimeMillis()) }
    }

    override suspend fun deleteAll() {
        rows.keys.forEach { delete(it) }
    }

    override suspend fun restore(id: String) {
        rows[id]?.let { rows[id] = it.copy(deletedAt = 0) }
    }

    override suspend fun setPinned(id: String, pinned: Boolean) {
        rows[id]?.let { rows[id] = it.copy(pinned = pinned) }
    }

    override suspend fun archive(id: String) {
        rows[id]?.let { rows[id] = it.copy(archivedAt = System.currentTimeMillis()) }
    }
}
