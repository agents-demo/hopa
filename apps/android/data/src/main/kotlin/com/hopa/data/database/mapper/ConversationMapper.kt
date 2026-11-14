package com.hopa.data.database.mapper

import com.hopa.data.database.entity.SessionEntity
import com.hopa.data.database.entity.TurnEntity
import com.hopa.data.sessions.ChatMessage
import com.hopa.data.sessions.Conversation

object ConversationMapper {
    fun conversation(session: SessionEntity, turns: List<TurnEntity>): Conversation =
        Conversation(
            id = session.id,
            title = session.title,
            messages = turns.map {
                ChatMessage(
                    id = it.id,
                    role = it.role,
                    text = it.text,
                    timestamp = it.timestamp,
                )
            },
            updatedAt = session.updatedAt,
            deletedAt = session.deletedAt,
            pinned = session.pinned,
            archivedAt = session.archivedAt,
        )

    fun turn(sessionId: String, message: ChatMessage): TurnEntity =
        TurnEntity(
            id = message.id,
            sessionId = sessionId,
            role = message.role,
            text = message.text,
            timestamp = message.timestamp,
        )
}
