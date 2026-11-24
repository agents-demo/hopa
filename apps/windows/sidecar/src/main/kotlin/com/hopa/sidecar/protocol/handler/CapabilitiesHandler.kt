package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.capabilities.CapabilitiesCollector
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject

/** The capabilities screen reads this one live summary. */
internal class CapabilitiesHandler(
    private val io: Stdio,
    private val collector: CapabilitiesCollector,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (!type.startsWith("capabilities.")) {
            return false
        }
        val id = message.text("id")
        if (type != "capabilities.summary") {
            io.send(Protocol.dataError(id, "capabilities", "E_UNSUPPORTED", "unknown capabilities command $type"))
            return true
        }

        io.send(Protocol.capabilities(id, runBlocking { collector.collect() }))
        return true
    }
}
