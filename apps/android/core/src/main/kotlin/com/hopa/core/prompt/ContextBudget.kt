package com.hopa.core.prompt

import com.hopa.core.model.ModelMessage

class ContextBudget(
    private val maxChars: Int = 24_000,
    private val keepLast: Int = 6,
    private val oldLineChars: Int = 400,
) {
    fun fit(history: List<ModelMessage>): List<ModelMessage> {
        if (history.isEmpty()) {
            return history
        }
        val cut = (history.size - keepLast).coerceAtLeast(0)
        val trimmed = history.mapIndexed { index, message ->
            if (index < cut && message.content.length > oldLineChars) {
                message.copy(content = message.content.take(oldLineChars - 1) + "…")
            } else {
                message
            }
        }.toMutableList()
        while (trimmed.size > 1 && trimmed.sumOf { it.content.length } > maxChars) {
            trimmed.removeAt(0)
        }
        return trimmed
    }
}
