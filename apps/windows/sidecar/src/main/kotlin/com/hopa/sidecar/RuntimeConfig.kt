package com.hopa.sidecar

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/**
 * W1 stores the host settings so W2 can use them. Secrets arrive once, in
 * memory, and are never logged or written to disk here.
 */
class RuntimeConfig {
    var bridgeUrl: String = ""
        private set
    var useBridge: Boolean = false
        private set
    var bridgeToken: String = ""
        private set
    var modelProvider: String = ""
        private set
    var modelBaseUrl: String = ""
        private set
    var modelKey: String = ""
        private set
    var tone: String = "warm"
        private set

    fun update(message: JsonObject) {
        bridgeUrl = message.text("bridgeUrl")
        useBridge = message.text("useBridge").toBoolean()
        bridgeToken = message.text("bridgeToken")
        modelProvider = message.text("modelProvider")
        modelBaseUrl = message.text("modelBaseUrl")
        modelKey = message.text("modelKey")
        tone = message.text("tone").ifBlank { "warm" }
    }

    /** Safe to log: no token, no key, no full path with credentials. */
    fun summary(): String =
        "bridge=${if (useBridge) "on" else "off"} url=${bridgeUrl.ifBlank { "-" }} " +
            "model=${modelProvider.ifBlank { "-" }} tone=$tone"

    private fun JsonObject.text(key: String): String =
        this[key]?.jsonPrimitive?.contentOrNull.orEmpty()
}
