package com.hopa.core.json

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

object CanonicalJson {
    fun encode(element: JsonElement): String = when (element) {
        is JsonObject -> element.entries
            .sortedBy { it.key }
            .joinToString(separator = ",", prefix = "{", postfix = "}") { entry ->
                "${JsonPrimitive(entry.key)}:${encode(entry.value)}"
            }

        is JsonArray -> element.joinToString(
            separator = ",",
            prefix = "[",
            postfix = "]",
            transform = ::encode,
        )

        is JsonNull -> "null"
        is JsonPrimitive -> element.toString()
    }
}
