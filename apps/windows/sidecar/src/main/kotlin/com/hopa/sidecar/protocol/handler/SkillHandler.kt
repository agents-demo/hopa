package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.store.SkillFileStore
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject

/** The skill family: the trigger → action pairs that ride in the prompt. */
internal class SkillHandler(
    private val io: Stdio,
    private val store: SkillFileStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (!type.startsWith("skills.")) {
            return false
        }
        val id = message.text("id")
        when (type) {
            "skills.list" -> list(id)
            "skills.add" -> {
                val trigger = message.text("trigger").trim()
                val action = message.text("action").trim()
                if (trigger.isEmpty() || action.isEmpty()) {
                    io.send(
                        Protocol.dataError(
                            id,
                            "skills",
                            "E_SCHEMA",
                            "skills.add needs a non-empty trigger and action",
                        ),
                    )
                } else {
                    runBlocking { store.add(trigger, action) }
                    list(id)
                }
            }

            "skills.delete" -> {
                val trigger = message.text("trigger").trim()
                if (trigger.isEmpty()) {
                    io.send(
                        Protocol.dataError(id, "skills", "E_SCHEMA", "skills.delete needs a non-empty trigger"),
                    )
                } else {
                    runBlocking { store.delete(trigger) }
                    list(id)
                }
            }

            "skills.clear" -> {
                runBlocking { store.clear() }
                list(id)
            }

            else -> io.send(Protocol.dataError(id, "skills", "E_UNSUPPORTED", "unknown skills command $type"))
        }
        return true
    }

    private fun list(id: String) {
        io.send(Protocol.skillList(id, runBlocking { store.all() }))
    }
}
