package com.hopa.sidecar.protocol.handlers

import com.hopa.contracts.chat.Attachment
import com.hopa.contracts.json.HopaJson
import com.hopa.sidecar.engine.Engine
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.support.Stdio
import kotlinx.serialization.json.JsonObject

/** Starting and cancelling a turn; the engine owns everything after that. */
internal class TurnHandler(
    private val io: Stdio,
    private val engine: Engine,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        when (type) {
            "turn.start" -> {
                val attachment = (message["attachment"] as? JsonObject)?.let {
                    HopaJson.element.decodeFromJsonElement(Attachment.serializer(), it)
                }
                engine.startTurn(
                    id = message.text("id"),
                    goal = message.text("goal"),
                    conversationId = message.text("conversationId").ifBlank { null },
                    attachment = attachment,
                )
            }

            "turn.cancel" -> {
                val turnId = message.text("id")
                if (turnId.isBlank()) engine.cancel() else engine.cancel(turnId)
            }

            else -> return false
        }
        return true
    }
}
