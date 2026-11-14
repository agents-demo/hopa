package com.hopa.sidecar

import com.hopa.data.sessions.ChatMessage
import com.hopa.data.sessions.Conversation
import java.nio.file.Files
import java.nio.file.Path
import java.util.UUID
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** W1: one JSON file of conversations; SQLite comes when it hurts. */
class ChatStore(path: Path) {
    private val file: Path = path
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    private var conversations: MutableList<Conversation> = load()

    fun list(): List<Conversation> =
        conversations.filter { it.deletedAt == 0L }.sortedByDescending { it.updatedAt }

    fun get(id: String): Conversation? = conversations.firstOrNull { it.id == id }

    fun create(): Conversation {
        val now = System.currentTimeMillis()
        val conversation = Conversation(id = "c-${UUID.randomUUID()}", title = "New chat", updatedAt = now)
        conversations.add(conversation)
        save()
        return conversation
    }

    fun append(conversationId: String, role: String, text: String): Conversation? {
        val index = conversations.indexOfFirst { it.id == conversationId }
        if (index < 0) {
            return null
        }

        val conversation = conversations[index]
        val now = System.currentTimeMillis()
        val message = ChatMessage(
            id = "m-$now-${UUID.randomUUID().toString().take(6)}",
            role = role,
            text = text,
            timestamp = now,
        )
        val title = if (conversation.title == "New chat" && role == "user" && text.isNotBlank()) {
            text.take(40)
        } else {
            conversation.title
        }
        val updated = conversation.copy(
            title = title,
            messages = conversation.messages + message,
            updatedAt = now,
        )
        conversations[index] = updated
        save()
        return updated
    }

    private fun load(): MutableList<Conversation> {
        if (!Files.exists(file)) {
            return mutableListOf()
        }
        return runCatching {
            json.decodeFromString(ListSerializer(Conversation.serializer()), Files.readString(file))
                .toMutableList()
        }.getOrElse { mutableListOf() }
    }

    private fun save() {
        runCatching {
            Files.createDirectories(file.parent)
            Files.writeString(file, json.encodeToString(ListSerializer(Conversation.serializer()), conversations))
        }
    }
}
