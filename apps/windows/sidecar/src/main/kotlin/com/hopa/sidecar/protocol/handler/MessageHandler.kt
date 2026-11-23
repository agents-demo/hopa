package com.hopa.sidecar.protocol.handler

import kotlinx.serialization.json.JsonObject

/**
 * One family of protocol messages. Returning false means "not mine", so the
 * dispatcher can try the next one and log what nobody claimed.
 */
internal interface MessageHandler {
    fun handle(type: String, message: JsonObject): Boolean
}
