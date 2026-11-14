package com.hopa.capabilities.bridge

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject

/** The conversation half of the bridge: one merged list for every device. */
interface ChatTransport {
    suspend fun push(sessions: JsonArray): JsonObject

    suspend fun pull(): JsonObject
}
