package com.hopa.sidecar.protocol.handlers

import com.hopa.sidecar.config.RuntimeConfig
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.support.Stdio
import kotlinx.serialization.json.JsonObject

/** Model and host settings the window sends before a turn. */
internal class ConfigHandler(
    private val io: Stdio,
    private val config: RuntimeConfig,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (type != "configure") return false
        config.update(message)
        io.log("configured: ${config.summary()}")
        io.send(Protocol.configured(message.text("id"), config.useBridge, config.modelProvider))
        return true
    }
}
