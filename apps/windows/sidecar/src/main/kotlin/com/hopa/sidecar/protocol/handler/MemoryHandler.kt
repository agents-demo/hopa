package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.store.MemoryFileStore
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject

/**
 * The memory family. A mutation replies with the new list, so the screen never
 * has to guess what the file now contains.
 */
internal class MemoryHandler(
    private val io: Stdio,
    private val store: MemoryFileStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (!type.startsWith("memory.")) {
            return false
        }
        val id = message.text("id")
        when (type) {
            "memory.list" -> list(id)
            "memory.add" -> {
                val text = message.text("text").trim()
                if (text.isEmpty()) {
                    io.send(Protocol.dataError(id, "memory", "E_SCHEMA", "memory.add needs non-empty text"))
                } else {
                    runBlocking { store.add(text) }
                    list(id)
                }
            }

            "memory.delete" -> {
                val text = message.text("text").trim()
                if (text.isEmpty()) {
                    io.send(Protocol.dataError(id, "memory", "E_SCHEMA", "memory.delete needs non-empty text"))
                } else {
                    runBlocking { store.delete(text) }
                    list(id)
                }
            }

            "memory.clear" -> {
                runBlocking { store.clear() }
                list(id)
            }

            else -> io.send(Protocol.dataError(id, "memory", "E_UNSUPPORTED", "unknown memory command $type"))
        }
        return true
    }

    private fun list(id: String) {
        io.send(Protocol.memoryList(id, runBlocking { store.all() }))
    }
}
