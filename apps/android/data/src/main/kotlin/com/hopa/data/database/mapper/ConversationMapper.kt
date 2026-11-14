package com.hopa.data.database.mapper

import com.hopa.data.database.entity.SessionEntity
import com.hopa.data.database.entity.TurnEntity
import com.hopa.data.sessions.Attachment
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
                    attachment = it.attachment(),
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
            attachmentName = message.attachment?.name.orEmpty(),
            attachmentMime = message.attachment?.mime.orEmpty(),
            attachmentBytes = message.attachment?.bytes ?: 0,
            attachmentPath = message.attachment?.path.orEmpty(),
        )

    private fun TurnEntity.attachment(): Attachment? =
        if (attachmentPath.isBlank() || attachmentName.isBlank()) {
            null
        } else {
            Attachment(
                name = attachmentName,
                mime = attachmentMime,
                bytes = attachmentBytes,
                path = attachmentPath,
            )
        }
}
