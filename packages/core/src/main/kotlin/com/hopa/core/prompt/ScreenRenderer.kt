package com.hopa.core.prompt

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode

class ScreenRenderer(
    private val maxLines: Int = 120,
) {
    fun render(observation: Observation): String {
        val lines = mutableListOf("SCREEN:", observation.text, "", "ELEMENTS:")
        append(observation.tree, lines)
        return lines.joinToString("\n")
    }

    private fun append(node: ObservationNode, lines: MutableList<String>) {
        if (lines.size >= maxLines) {
            return
        }
        if (node.ref.isNotEmpty()) {
            val bounds = node.bounds?.joinToString(",") ?: ""
            val label = node.text.ifEmpty { node.description }
            lines += "${node.ref} ${node.type} ${label} [$bounds]"
        }
        for (child in node.children) {
            if (lines.size >= maxLines) {
                return
            }
            append(child, lines)
        }
    }
}
