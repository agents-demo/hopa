package com.hopa.sidecar

import com.hopa.data.sessions.Conversation
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/** The NDJSON messages between the .NET host and this sidecar. */
object Protocol {
    const val VERSION = 1
    private val json = Json { encodeDefaults = true }

    fun ready(): JsonObject = buildJsonObject {
        put("type", "ready")
        put("version", VERSION)
    }

    fun log(text: String): JsonObject = buildJsonObject {
        put("type", "log")
        put("text", text)
    }

    fun turnEnd(id: String, conversationId: String, title: String, answer: String): JsonObject =
        buildJsonObject {
            put("type", "turn.end")
            put("id", id)
            put("conversationId", conversationId)
            put("title", title)
            put("answer", answer)
        }

    fun conversationList(id: String, items: List<Conversation>): JsonObject = buildJsonObject {
        put("type", "conversations.list")
        put("id", id)
        put("items", buildJsonArray {
            items.forEach { add(json.encodeToJsonElement(Conversation.serializer(), it)) }
        })
    }

    fun conversationOpened(id: String, conversation: Conversation?): JsonObject = buildJsonObject {
        put("type", "conversation.history")
        put("id", id)
        if (conversation != null) {
            put("conversation", json.encodeToJsonElement(Conversation.serializer(), conversation))
        }
    }

    fun configured(id: String, bridge: Boolean, model: String): JsonObject = buildJsonObject {
        put("type", "configured")
        put("id", id)
        put("bridge", bridge)
        put("model", model)
    }

    fun deviceRequest(id: String, op: String, fields: JsonObjectBuilder.() -> Unit): JsonObject =
        buildJsonObject {
            put("type", "device.request")
            put("id", id)
            put("op", op)
            fields()
        }

    fun String.asObject(): JsonObject? = runCatching {
        json.parseToJsonElement(this).let { it as? JsonObject }
    }.getOrNull()

    fun JsonObject.type(): String? = this["type"]?.jsonPrimitive?.contentOrNull

    fun JsonObject.text(key: String): String = this[key]?.jsonPrimitive?.contentOrNull.orEmpty()

    fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.contentOrNull?.toIntOrNull()
}
