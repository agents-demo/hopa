package com.hopa.sidecar

import com.hopa.core.model.ModelPort
import com.hopa.core.model.ModelReply
import com.hopa.core.model.ModelRequest

/**
 * W0 only: a scripted stand-in for a real model.
 *
 * "click" produces one `ui.tap` decision so the device seam is exercised; any
 * other goal is answered in plain text. W2 replaces this with the real clients
 * from `packages/capabilities`.
 */
class SpikeModel : ModelPort {
    override suspend fun complete(request: ModelRequest): ModelReply {
        val goal = request.messages
            .lastOrNull { it.role == "user" && !it.content.startsWith("SCREEN:") }
            ?.content
            .orEmpty()
        val lastAssistant = request.messages.lastOrNull { it.role == "assistant" }?.content.orEmpty()
        if (goal.contains("click", ignoreCase = true) && !lastAssistant.contains("\"ui.tap\"")) {
            return ModelReply("""{"schemaVersion":"1","kind":"ui.tap","x":700,"y":600,"timeoutMs":5000}""")
        }
        return ModelReply("Sidecar answered: \"${goal.take(80)}\".")
    }
}
