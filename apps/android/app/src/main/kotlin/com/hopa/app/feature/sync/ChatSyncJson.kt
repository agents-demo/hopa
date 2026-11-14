package com.hopa.app.feature.sync

import com.hopa.data.sessions.ChatMessage
import com.hopa.data.sessions.Conversation
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

/** The session JSON both HOPA and the bridge's `ChatStore` agree on. */
object ChatSyncJson {
    fun encode(session: Conversation): JsonObject = buildJsonObject {
        put("id", session.id)
        put("title", session.title)
        put("titleAt", session.updatedAt)
        put("created", session.messages.firstOrNull()?.timestamp ?: session.updatedAt)
        put("updated", session.updatedAt)
        put("deletedAt", session.deletedAt)
        put(
            "turns",
            buildJsonArray {
                session.messages.forEach { message ->
                    add(
                        buildJsonObject {
                            put("id", message.id)
                            put("role", message.role)
                            put("text", message.text)
                            put("at", message.timestamp)
                        },
                    )
                }
            },
        )
    }

    fun decode(node: JsonObject): Conversation {
        val turns = node["turns"]?.jsonArray.orEmpty().mapNotNull { entry ->
            val turn = entry.jsonObject
            val text = turn["text"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
            val role = turn["role"]?.jsonPrimitive?.contentOrNull ?: "assistant"
            val at = turn["at"]?.jsonPrimitive?.longOrNull ?: 0L
            val id = turn["id"]?.jsonPrimitive?.contentOrNull?.takeIf { it.isNotBlank() }
                ?: "t-$role-$at-${text.hashCode()}"
            ChatMessage(id = id, role = role, text = text, timestamp = at)
        }.sortedBy { it.timestamp }
        return Conversation(
            id = node["id"]?.jsonPrimitive?.contentOrNull.orEmpty(),
            title = node["title"]?.jsonPrimitive?.contentOrNull.orEmpty().ifBlank { "New chat" },
            messages = turns,
            updatedAt = node["updated"]?.jsonPrimitive?.longOrNull ?: 0,
            deletedAt = node["deletedAt"]?.jsonPrimitive?.longOrNull ?: 0,
        )
    }
}
