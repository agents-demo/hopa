package com.hopa.data.sessions

import com.hopa.data.database.HopaDatabase
import com.hopa.data.database.entity.SessionEntity
import com.hopa.data.database.mapper.ConversationMapper
import java.util.UUID

class RoomConversationStore(
    database: HopaDatabase,
) : ConversationStore {
    private val sessions = database.sessionDao()
    private val turns = database.turnDao()

    override suspend fun all(): List<Conversation> = conversations(sessions.all())

    override suspend fun allWithDeleted(): List<Conversation> = conversations(sessions.allRows())

    override suspend fun dropLastExchange(id: String) {
        turns.dropLast(id, 2)
        sessions.touch(id, System.currentTimeMillis())
    }

    override suspend fun adopt(session: Conversation) {
        val existing = sessions.byId(session.id)
        if (existing == null) {
            sessions.replace(
                SessionEntity(
                    id = session.id,
                    title = session.title.ifBlank { "New chat" },
                    updatedAt = session.updatedAt,
                    deletedAt = session.deletedAt,
                    pinned = session.pinned,
                    archivedAt = session.archivedAt,
                ),
            )
        } else {
            sessions.replace(
                existing.copy(
                    title = session.title.takeIf { it.isNotBlank() } ?: existing.title,
                    updatedAt = maxOf(existing.updatedAt, session.updatedAt),
                    deletedAt = maxOf(existing.deletedAt, session.deletedAt),
                    pinned = existing.pinned || session.pinned,
                    archivedAt = maxOf(existing.archivedAt, session.archivedAt),
                ),
            )
        }
        session.messages.forEach { message ->
            val row = ConversationMapper.turn(session.id, message)
            val local = turns.byId(row.id)
            // A snapshot from the bridge carries text only; keep local bytes.
            turns.insert(
                if (local == null || message.attachment != null) {
                    row
                } else {
                    row.copy(
                        attachmentName = local.attachmentName,
                        attachmentMime = local.attachmentMime,
                        attachmentBytes = local.attachmentBytes,
                        attachmentPath = local.attachmentPath,
                    )
                },
            )
        }
    }

    override suspend fun search(query: String): List<Conversation> =
        conversations(sessions.search(query))

    private suspend fun conversations(rows: List<SessionEntity>):
        List<Conversation> = rows.map { session ->
        ConversationMapper.conversation(session, turns.forSession(session.id))
    }

    override suspend fun create(): Conversation {
        // Reuse one empty draft instead of piling up empty "New chat" rows.
        val existing = sessions.draft()
        if (existing != null && turns.forSession(existing.id).isEmpty()) {
            return ConversationMapper.conversation(existing, emptyList())
        }
        val now = System.currentTimeMillis()
        val session = SessionEntity(
            id = "c-$now-${UUID.randomUUID().toString().take(6)}",
            title = "New chat",
            updatedAt = now,
        )
        sessions.insert(session)
        return ConversationMapper.conversation(session, emptyList())
    }

    override suspend fun append(id: String, message: ChatMessage) {
        val session = sessions.byId(id) ?: return
        turns.insert(ConversationMapper.turn(id, message))
        val title = if (session.title == "New chat" && message.role == "user") {
            message.text.take(40)
        } else {
            session.title
        }
        sessions.updateMeta(id, title, message.timestamp)
    }

    override suspend fun rename(id: String, title: String) {
        sessions.rename(id, title)
    }

    override suspend fun delete(id: String) {
        sessions.tombstone(id, System.currentTimeMillis())
    }

    override suspend fun deleteAll() {
        sessions.tombstoneAll(System.currentTimeMillis())
    }

    override suspend fun restore(id: String) {
        sessions.restore(id)
    }

    override suspend fun setPinned(id: String, pinned: Boolean) {
        sessions.setPinned(id, pinned)
    }

    override suspend fun archive(id: String) {
        sessions.archive(id, System.currentTimeMillis())
    }
}
