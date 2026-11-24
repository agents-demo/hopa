package com.hopa.sidecar.protocol.handler

import com.hopa.contracts.chat.Attachment
import com.hopa.agent.goal.Checkpoint
import com.hopa.contracts.json.HopaJson
import com.hopa.sidecar.turn.TurnEngine
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/** Starting and cancelling a turn; the engine owns everything after that. */
internal class TurnHandler(
    private val io: Stdio,
    private val engine: TurnEngine,
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
                    planApproved = message.text("planApproved").toBoolean(),
                    checkpoints = (message["checkpoints"] as? JsonArray)
                        ?.mapNotNull { it.jsonPrimitive.contentOrNull }
                        ?.filter { it.isNotBlank() }
                        ?.map { Checkpoint(anchor = it) }
                        .orEmpty(),
                )
            }

            "turn.cancel" -> {
                val turnId = message.text("id")
                if (turnId.isBlank()) engine.cancel() else engine.cancel(turnId)
            }

            "turn.pause" -> engine.pause()

            "turn.resume" -> engine.resume()

            else -> return false
        }
        return true
    }
}
