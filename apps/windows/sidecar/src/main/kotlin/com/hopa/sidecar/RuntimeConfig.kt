package com.hopa.sidecar

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/**
 * The host settings, held in memory. Secrets arrive once and are never logged
 * or written to disk here.
 */
class RuntimeConfig {
    var bridgeUrl: String = ""
        private set
    var useBridge: Boolean = false
        private set
    var bridgeToken: String = ""
        private set
    var modelProvider: String = "openai"
        private set
    var modelBaseUrl: String = ""
        private set
    var modelKey: String = ""
        private set
    var modelName: String = "gpt-4o-mini"
        private set
    var tone: String = "warm"
        private set

    val hasBridge: Boolean
        get() = useBridge && bridgeUrl.isNotBlank() && bridgeToken.isNotBlank()

    val hasModel: Boolean
        get() = modelKey.isNotBlank()

    fun update(message: JsonObject) {
        bridgeUrl = message.text("bridgeUrl")
        useBridge = message.text("useBridge").toBoolean()
        bridgeToken = message.text("bridgeToken")
        modelProvider = message.text("modelProvider").ifBlank { "openai" }
        modelBaseUrl = message.text("modelBaseUrl")
        modelKey = message.text("modelKey")
        modelName = message.text("modelName").ifBlank { "gpt-4o-mini" }
        tone = message.text("tone").ifBlank { "warm" }
    }

    /** Safe to log: no token, no key, no credentials in the URL. */
    fun summary(): String =
        "bridge=${if (hasBridge) "on" else "off"} url=${bridgeUrl.ifBlank { "-" }} " +
            "model=${if (hasModel) modelProvider else "none"} tone=$tone"

    private fun JsonObject.text(key: String): String =
        this[key]?.jsonPrimitive?.contentOrNull.orEmpty()
}
