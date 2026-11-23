package com.hopa.sidecar.protocol.handlers

import com.hopa.sidecar.config.RuntimeConfig
import com.hopa.sidecar.device.HostDevice
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.support.Stdio
import kotlinx.serialization.json.JsonObject

/**
 * The device answers a question the engine asked (`device.result`), and the host
 * reports whether a phone peer is reachable (`gateway.state`) so an approval can
 * be attributed honestly.
 */
internal class DeviceHandler(
    private val io: Stdio,
    private val device: HostDevice,
    private val config: RuntimeConfig,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        when (type) {
            "device.result" -> device.resolve(message.text("id"), message)

            "gateway.state" -> config.setGatewayState(
                paired = message.text("paired").toBoolean(),
                phoneOnline = message.text("phoneOnline").toBoolean(),
            )

            else -> {
                io.log("unknown device message: $type")
                return false
            }
        }
        return true
    }
}
