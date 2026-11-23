package com.hopa.sidecar.protocol.handlers

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.store.Attachments
import com.hopa.sidecar.protocol.Stdio
import java.nio.file.Path
import kotlinx.serialization.json.JsonObject

/** Attaching and removing a file the window handed over by path. */
internal class FileHandler(
    private val io: Stdio,
    private val attachments: Attachments,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        when (type) {
            "file.attach" -> {
                val path = message.text("path")
                val result = runCatching { attachments.accept(Path.of(path)) }
                io.send(
                    Protocol.fileAttached(
                        id = message.text("id"),
                        attachment = result.getOrNull(),
                        error = result.exceptionOrNull()?.message,
                    ),
                )
            }

            "file.remove" -> {
                attachments.remove(message.text("path"))
                io.send(Protocol.fileRemoved(message.text("id"), true))
            }

            else -> return false
        }
        return true
    }
}
