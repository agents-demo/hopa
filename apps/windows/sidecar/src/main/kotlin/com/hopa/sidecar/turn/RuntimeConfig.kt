package com.hopa.sidecar.turn

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
    var bridgeRefresh: String = ""
        private set
    var modelProvider: String = "openai"
        private set
    var modelBaseUrl: String = ""
        private set
    var modelKey: String = ""
        private set
    var modelName: String = "gpt-4o-mini"
        private set
    /** The person allowed a failed local turn to continue on the API. */
    var cloudFallback: Boolean = false
        private set
    var fallbackProvider: String = "openai"
        private set
    var fallbackBaseUrl: String = ""
        private set
    var fallbackModelName: String = ""
        private set
    var fallbackModelKey: String = ""
        private set
    var tone: String = "warm"
        private set
    /** The shell profile; the catalogue is shared in com.hopa.stores.Profiles. */
    var profile: String = "everyday"
        private set
    /** `auto` uses recipes and instant commands; `model` skips both. */
    var stepSource: String = "auto"
        private set
    /** Try a stored recipe before the model. */
    var replay: Boolean = true
        private set
    /** Attach a screenshot to each model call when the model accepts images. */
    var vision: Boolean = false
        private set
    /** Ask for a plan first; the host shows it and sends the approved goal again. */
    var planFirst: Boolean = false
        private set
    /** Run a recognized launch/back/home/scroll command without the model. */
    var instantCommands: Boolean = true
        private set
    /** P4: this PC has its own gateway credential and a phone peer online. */
    var gatewayPaired: Boolean = false
        private set
    var gatewayPhoneOnline: Boolean = false
        private set

    val hasBridge: Boolean
        get() = useBridge && bridgeUrl.isNotBlank() && bridgeToken.isNotBlank()

    /** A phone answer can only have crossed the gateway when this is true. */
    val hasPhoneLink: Boolean
        get() = gatewayPaired && gatewayPhoneOnline

    val hasModel: Boolean
        get() = modelKey.isNotBlank()

    /**
     * Fallback exists only for a local turn, only with the person's consent,
     * and only when the API has an address, a model and a key. Anything less
     * stays local rather than pretending the API is ready.
     */
    val hasFallback: Boolean
        get() = modelProvider.equals("on-device", ignoreCase = true) &&
            cloudFallback &&
            !fallbackProvider.equals("stub", ignoreCase = true) &&
            fallbackBaseUrl.isNotBlank() &&
            fallbackModelName.isNotBlank() &&
            fallbackModelKey.isNotBlank()

    fun setGatewayState(paired: Boolean, phoneOnline: Boolean) {
        gatewayPaired = paired
        gatewayPhoneOnline = phoneOnline
    }

    fun setSession(token: String, refresh: String) {
        bridgeToken = token
        bridgeRefresh = refresh
    }

    fun setProfile(value: String) {
        profile = value
    }

    fun update(message: JsonObject) {        bridgeUrl = message.text("bridgeUrl")
        useBridge = message.text("useBridge").toBoolean()
        bridgeToken = message.text("bridgeToken")
        bridgeRefresh = message.text("bridgeRefresh")
        modelProvider = message.text("modelProvider").ifBlank { "openai" }
        modelBaseUrl = message.text("modelBaseUrl")
        modelKey = message.text("modelKey")
        modelName = message.text("modelName").ifBlank { "gpt-4o-mini" }
        cloudFallback = message.bool("cloudFallback", false)
        fallbackProvider = message.text("fallbackProvider").ifBlank { "openai" }
        fallbackBaseUrl = message.text("fallbackBaseUrl")
        fallbackModelName = message.text("fallbackModelName")
        fallbackModelKey = message.text("fallbackModelKey")
        tone = message.text("tone").ifBlank { "warm" }
        profile = message.text("profile").ifBlank { profile }
        stepSource = message.text("stepSource").lowercase().let {
            if (it == "model" || it == "anchors") it else "auto"
        }
        replay = message.bool("replay", replay)
        vision = message.bool("vision", vision)
        planFirst = message.bool("planFirst", planFirst)
        instantCommands = message.bool("instantCommands", instantCommands)
    }

    /** Safe to log: no token, no key, no credentials in the URL. */
    fun summary(): String =
        "bridge=${if (hasBridge) "on" else "off"} url=${bridgeUrl.ifBlank { "-" }} " +
            "gateway=${if (gatewayPaired) "paired" else "off"}" +
            "/phone=${if (gatewayPhoneOnline) "on" else "off"} " +
            "model=${when {
                modelProvider.equals("stub", ignoreCase = true) -> "demo"
                hasModel -> modelProvider
                else -> "none"
            }} fallback=${if (hasFallback) fallbackProvider else "off"} " +
            "steps=$stepSource tone=$tone profile=$profile"

    private fun JsonObject.text(key: String): String =
        this[key]?.jsonPrimitive?.contentOrNull.orEmpty()

    private fun JsonObject.bool(key: String, fallback: Boolean): Boolean =
        this[key]?.jsonPrimitive?.contentOrNull?.toBooleanStrictOrNull() ?: fallback
}
