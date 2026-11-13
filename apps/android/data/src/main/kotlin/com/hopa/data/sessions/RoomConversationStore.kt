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

    override suspend fun all(): List<Conversation> = sessions.all().map { session ->
        ConversationMapper.conversation(session, turns.forSession(session.id))
    }

    override suspend fun create(): Conversation {
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
}
