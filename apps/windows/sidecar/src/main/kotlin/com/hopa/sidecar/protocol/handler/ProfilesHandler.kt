package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.turn.RuntimeConfig
import com.hopa.stores.Profiles
import kotlinx.serialization.json.JsonObject

/** The shared profile catalogue and the current shell. */
internal class ProfilesHandler(
    private val io: Stdio,
    private val config: RuntimeConfig,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (!type.startsWith("profiles.")) {
            return false
        }
        val id = message.text("id")
        when (type) {
            "profiles.list" -> list(id)
            "profiles.select" -> {
                val key = message.text("profile").trim()
                if (Profiles.find(key) == null) {
                    io.send(Protocol.dataError(id, "profiles", "E_SCHEMA", "unknown profile '$key'"))
                } else {
                    config.setProfile(key)
                    list(id)
                }
            }

            else -> io.send(Protocol.dataError(id, "profiles", "E_UNSUPPORTED", "unknown profiles command $type"))
        }
        return true
    }

    private fun list(id: String) =
        io.send(Protocol.profileList(id, Profiles.all, config.profile))
}
