package com.hopa.sidecar

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/** The NDJSON messages between the .NET host and this sidecar. */
object Protocol {
    const val VERSION = 1

    fun ready(): JsonObject = buildJsonObject {
        put("type", "ready")
        put("version", VERSION)
    }

    fun log(text: String): JsonObject = buildJsonObject {
        put("type", "log")
        put("text", text)
    }

    fun turnEnd(id: String, answer: String): JsonObject = buildJsonObject {
        put("type", "turn.end")
        put("id", id)
        put("answer", answer)
    }

    fun deviceRequest(id: String, op: String, fields: JsonObjectBuilder.() -> Unit): JsonObject =
        buildJsonObject {
            put("type", "device.request")
            put("id", id)
            put("op", op)
            fields()
        }

    fun String.asObject(): JsonObject? = runCatching {
        Json.parseToJsonElement(this).let { it as? JsonObject }
    }.getOrNull()

    fun JsonObject.type(): String? = this["type"]?.jsonPrimitive?.contentOrNull

    fun JsonObject.text(key: String): String = this[key]?.jsonPrimitive?.contentOrNull.orEmpty()

    fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.contentOrNull?.toIntOrNull()
}
