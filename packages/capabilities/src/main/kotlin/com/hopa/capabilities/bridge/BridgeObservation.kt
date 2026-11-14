package com.hopa.capabilities.bridge

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.observation.ObservationHasher
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Turns the bridge's flat node list into the shared observation tree. */
object BridgeObservation {
    fun fromJson(
        payload: JsonObject,
        app: String,
        timestamp: Long,
        id: String,
    ): Observation {
        val width = payload["width"]?.jsonPrimitive?.intOrNull ?: 0
        val height = payload["height"]?.jsonPrimitive?.intOrNull ?: 0
        val nodes = payload["nodes"]?.jsonArray.orEmpty().map { entry ->
            val item = entry.jsonObject
            ObservationNode(
                ref = item.string("ref"),
                type = item.string("type"),
                text = item.string("text"),
                description = item.string("description"),
                id = item.string("id"),
                bounds = item["bounds"]?.jsonArray?.mapNotNull {
                    it.jsonPrimitive.intOrNull
                }?.takeIf { it.size == 4 },
                clickable = item["clickable"]?.jsonPrimitive?.contentOrNull == "true",
            )
        }
        val text = payload["text"]?.jsonPrimitive?.contentOrNull.orEmpty()
        val observation = Observation(
            id = id,
            timestamp = timestamp,
            screenSize = ScreenSize(width = width, height = height),
            text = text,
            tree = ObservationNode(type = "root", children = nodes),
            app = app,
        )
        return observation.copy(hash = ObservationHasher.hash(observation))
    }

    private fun JsonObject.string(name: String): String =
        this[name]?.jsonPrimitive?.contentOrNull.orEmpty()
}
