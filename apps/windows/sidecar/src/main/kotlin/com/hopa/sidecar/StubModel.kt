package com.hopa.sidecar

import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest

/**
 * P1: the deterministic stand-in for a model.
 *
 * It is a **proposer, never an approver**. The text it returns may become one
 * action, and the real `ApprovalPolicy` in `packages/core` decides whether that
 * action runs. It has no network, no clock and no state, so a headless turn is
 * reproducible.
 *
 * The script is deliberately small and explicit. A real provider replaces it
 * when a key is configured; `--stub-model` keeps it available for tests and
 * demos.
 */
class StubModel : ModelPort {
    override suspend fun complete(request: ModelRequest): ModelReply {
        val goal = request.messages
            .lastOrNull { it.role == "user" && !it.content.startsWith("SCREEN") }
            ?.content
            .orEmpty()
        val lastAssistant = request.messages.lastOrNull { it.role == "assistant" }?.content.orEmpty()

        // If the gate or the device already refused, say exactly that and stop.
        // The loop appends the executor's line as a user message; echoing it keeps
        // the turn honest instead of inventing a success.
        val refusal = request.messages
            .lastOrNull { message ->
                message.role == "user" &&
                    REFUSAL_PREFIXES.any { prefix -> message.content.startsWith(prefix) }
            }
            ?.content
        if (refusal != null) {
            return ModelReply(refusal)
        }

        val already = { needle: String -> lastAssistant.contains(needle) }
        return ModelReply(
            when {
                // Payment always asks. This only *proposes* it; the gate denies.
                // The kind needs a point, or the parser refuses it as malformed.
                goal.contains("pay", ignoreCase = true) && !already("\"payment.pay\"") ->
                    """{"schemaVersion":"1","kind":"payment.pay","app":"bank","text":"100","x":640,"y":480}"""

                goal.contains("click", ignoreCase = true) && !already("\"ui.tap\"") ->
                    """{"schemaVersion":"1","kind":"ui.tap","x":700,"y":600,"timeoutMs":5000}"""

                goal.contains("open notepad", ignoreCase = true) && !already("\"ui.launch\"") ->
                    """{"schemaVersion":"1","kind":"ui.launch","app":"notepad","timeoutMs":8000}"""

                goal.contains("open settings", ignoreCase = true) && !already("\"ui.launch\"") ->
                    """{"schemaVersion":"1","kind":"ui.launch","app":"com.android.settings","timeoutMs":8000}"""

                goal.contains("type", ignoreCase = true) && !already("\"ui.type\"") ->
                    """{"schemaVersion":"1","kind":"ui.type","text":"hello from HOPA"}"""

                else -> plainAnswer(goal)
            },
        )
    }

    private fun plainAnswer(goal: String): String =
        if (goal.isBlank()) "I did not catch a request." else "Stub answered: \"${goal.take(80)}\"."

    private companion object {
        val REFUSAL_PREFIXES = listOf("I did not run that.", "I could not do that:")
    }
}
