package com.hopa.agent.decision.tree

import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import java.util.Locale

/**
 * The candidates a tree ranker scores.
 *
 * The list is built the way the AndroidControl fine-tune was trained: the
 * visible, labelled, interactive nodes of the accessibility tree, each as
 * `click <label>`, `type <label>: <payload>` or `scroll down <label>`, plus
 * `task complete done`, back and home. The label is the first of text,
 * description, the resource-id tail or the class, as the training pipeline did;
 * the screen summary joins every visible labelled node and is capped at 800
 * characters, so headings that are not tappable still reach the model.
 *
 * The ranker never invents a node and never sees a ref: [TreeCandidate] keeps
 * the ref only so the policy can turn the winner back into an [com.hopa.contracts.wire.Action].
 */
internal data class TreeCandidate(
    val label: String,
    val kind: Kind,
    /** The screen label, without the action words; what the model sees as context. */
    val screenLabel: String = "",
    val ref: String = "",
    val text: String? = null,
    val x: Int = 0,
    val y: Int = 0,
) {
    enum class Kind { TAP, TYPE, SCROLL, BACK, HOME, DONE }
}

internal object TreeCandidates {

    /** The training pipeline stopped at 29 nodes before adding back/home. */
    const val MAX_NODES = 29

    private const val MAX_LABEL = 120
    private const val MAX_SCREEN = 800

    fun build(goal: String, observation: Observation, maxNodes: Int = MAX_NODES): List<TreeCandidate> {
        val payload = typePayload(goal)
        val out = ArrayList<TreeCandidate>(maxNodes + 3)
        var added = 0

        fun visit(node: ObservationNode) {
            if (added >= maxNodes) return
            if (!node.visible) return
            val label = labelOf(node)
            if (node.ref.isNotBlank() && label.isNotBlank()) {
                val x = center(node.bounds, 0)
                val y = center(node.bounds, 1)
                if (isEditable(node)) {
                    out += TreeCandidate(
                        label = "type $label: $payload",
                        kind = TreeCandidate.Kind.TYPE,
                        screenLabel = label,
                        ref = node.ref,
                        text = payload,
                        x = x,
                        y = y,
                    )
                    added++
                }
                if (node.clickable && added < maxNodes) {
                    out += TreeCandidate(
                        label = "click $label",
                        kind = TreeCandidate.Kind.TAP,
                        screenLabel = label,
                        ref = node.ref,
                        x = x,
                        y = y,
                    )
                    added++
                }
                if (node.scrollable && added < maxNodes) {
                    out += TreeCandidate(
                        label = "scroll down $label",
                        kind = TreeCandidate.Kind.SCROLL,
                        screenLabel = label,
                        ref = node.ref,
                        x = x,
                        y = y,
                    )
                    added++
                }
            }
            for (child in node.children) {
                if (added >= maxNodes) return
                visit(child)
            }
        }

        visit(observation.tree)
        out += TreeCandidate(label = "task complete done", kind = TreeCandidate.Kind.DONE)
        out += TreeCandidate(label = "navigate back", kind = TreeCandidate.Kind.BACK)
        out += TreeCandidate(label = "navigate home", kind = TreeCandidate.Kind.HOME)
        return out
    }

    /** `label | label` over every visible labelled node; the screen half of the pair. */
    fun summary(observation: Observation): String {
        val labels = ArrayList<String>(64)

        fun visit(node: ObservationNode) {
            if (!node.visible) return
            val named = node.text.ifBlank { node.description }.ifBlank { node.id.substringAfterLast('/') }
            val label = named.ifBlank {
                if (node.clickable || node.scrollable) node.type else ""
            }
            if (label.isNotBlank()) {
                labels += label.trim().replace(Regex("\\s+"), " ").take(MAX_LABEL)
            }
            for (child in node.children) visit(child)
        }

        visit(observation.tree)
        return labels.joinToString(" | ").take(MAX_SCREEN)
    }

    /**
     * The data the fine-tune expects when the goal says what to type: "send a
     * message to Liat that I will be late" types "I will be late".
     */
    fun typePayload(goal: String): String {
        val lower = goal.lowercase(Locale.US)
        val that = lower.indexOf(" that ")
        if (that > 0 && that + 6 < goal.length) {
            return goal.substring(that + 6).trim()
        }
        val saying = lower.indexOf(" saying ")
        if (saying > 0 && saying + 8 < goal.length) {
            return goal.substring(saying + 8).trim()
        }
        return goal.take(64)
    }

    private fun labelOf(node: ObservationNode): String {
        val raw = node.text
            .ifBlank { node.description }
            .ifBlank { node.id.substringAfterLast('/') }
            .ifBlank { node.type }
        return raw.trim().replace(Regex("\\s+"), " ").take(MAX_LABEL)
    }

    private fun isEditable(node: ObservationNode): Boolean {
        val type = node.type.lowercase(Locale.US)
        return type.contains("edittext") ||
            type.contains("textfield") ||
            type.contains("autocomplete") ||
            type.contains("searchview")
    }

    /** bounds is `[left, top, right, bottom]`; 0 when the tree gave none. */
    private fun center(bounds: List<Int>?, axis: Int): Int {
        if (bounds == null || bounds.size < 4) return 0
        return if (axis == 0) {
            (bounds[0] + bounds[2]) / 2
        } else {
            (bounds[1] + bounds[3]) / 2
        }
    }
}
