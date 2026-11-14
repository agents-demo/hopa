package com.hopa.core.observation

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.json.CanonicalJson
import java.security.MessageDigest
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

object ObservationHasher {
    fun hash(observation: Observation): String {
        val payload = buildJsonObject {
            put("displayId", observation.displayId)
            put("windowId", observation.windowId)
            put("rotation", observation.rotation)
            put("width", observation.screenSize.width)
            put("height", observation.screenSize.height)
            put("focus", observation.focus)
            put("text", observation.text)
            put("tree", toJson(observation.tree))
        }
        return "sha256:" + sha256(CanonicalJson.encode(payload))
    }

    private fun toJson(value: ObservationNode): JsonObject = buildJsonObject {
        put("ref", value.ref)
        put("type", value.type)
        put("text", value.text)
        put("description", value.description)
        put("id", value.id)
        put(
            "bounds",
            value.bounds?.let { bounds ->
                buildJsonArray { bounds.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) } }
            } ?: JsonNull,
        )
        put("clickable", value.clickable)
        put("enabled", value.enabled)
        put("checked", value.checked)
        put("scrollable", value.scrollable)
        put("visible", value.visible)
        put("focused", value.focused)
        put("children", buildJsonArray { value.children.forEach { add(toJson(it)) } })
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }
}
