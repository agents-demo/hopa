package com.hopa.sidecar.protocol

import com.hopa.sidecar.protocol.Protocol.asObject
import com.hopa.sidecar.protocol.Protocol.type
import com.hopa.sidecar.protocol.handlers.MessageHandler

/**
 * One NDJSON line in, one message out. It knows the envelope (`hello`,
 * `shutdown`, unknown) and nothing about conversations, turns or tasks; those
 * belong to the handlers.
 */
internal class Dispatcher(
    private val io: Stdio,
    private val handlers: List<MessageHandler>,
) {
    /** Returns false when the window asked to shut down. */
    fun handle(line: String): Boolean {
        if (line.isBlank()) return true
        val message = line.asObject() ?: return true
        val type = message.type() ?: return true
        when (type) {
            "hello" -> {
                io.send(Protocol.ready())
                return true
            }

            "shutdown" -> return false
        }
        for (handler in handlers) {
            if (handler.handle(type, message)) {
                return true
            }
        }
        io.log("unknown message: $type")
        return true
    }
}
