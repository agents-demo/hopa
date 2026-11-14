package com.hopa.core.observation

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode

/**
 * Turns a raw screen tree into the observation the contract describes: refs in
 * pre-order, password fields dropped, emails/phones/cards/codes redacted, the
 * node and text caps applied, and the canonical hash attached.
 *
 * The producer is idempotent for an observation that already carries refs and
 * fits the caps, which is what lets the hash fixtures round-trip.
 */
class ObservationProducer(
    private val limits: ObservationLimits = ObservationLimits(),
) {
    fun produce(raw: Observation): Observation {
        val flat = mutableListOf<Item>()
        flatten(raw.tree, parent = -1, parentDropped = false, into = flat)
        val focusPath = focusPath(flat)
        val kept = select(flat, focusPath)
        val tree = rebuild(kept)

        val redactedText = redact(raw.text)
        val text = redactedText.take(limits.maxTextChars)
        val truncated = raw.truncated ||
            kept.size < flat.size ||
            redactedText.length > text.length

        val normalized = raw.copy(text = text, tree = tree, truncated = truncated, hash = "")
        return normalized.copy(hash = ObservationHasher.hash(normalized))
    }

    private fun flatten(
        node: ObservationNode,
        parent: Int,
        parentDropped: Boolean,
        into: MutableList<Item>,
    ) {
        val index = into.size
        val dropped = parentDropped || isSecret(node)
        into += Item(node, parent, dropped)
        for (child in node.children) {
            flatten(child, index, dropped, into)
        }
    }

    private fun focusPath(flat: List<Item>): Set<Int> {
        val focused = flat.indexOfLast { it.node.focused && !it.dropped }
        if (focused < 0) {
            return emptySet()
        }
        val path = mutableSetOf<Int>()
        var cursor = focused
        while (cursor >= 0) {
            path += cursor
            cursor = flat[cursor].parent
        }
        return path
    }

    private fun select(flat: List<Item>, focusPath: Set<Int>): List<Kept> {
        val kept = mutableListOf<Kept>()
        val newIndex = mutableMapOf<Int, Int>()
        val reserve = focusPath.count { index -> !flat[index].dropped }
        val budget = (limits.maxNodes - reserve).coerceAtLeast(0)
        var regular = 0
        var refs = 0
        for ((index, item) in flat.withIndex()) {
            if (item.dropped) {
                continue
            }
            if (index !in focusPath) {
                if (regular >= budget) {
                    continue
                }
                regular += 1
            }
            val parentIndex = item.parent
            val newParent = if (parentIndex < 0) {
                -1
            } else {
                newIndex[parentIndex] ?: continue
            }
            val node = item.node.copy(
                ref = item.node.ref.ifBlank { "e${++refs}" },
                text = redact(item.node.text),
                description = redact(item.node.description),
                children = emptyList(),
            )
            kept += Kept(newParent, node)
            newIndex[index] = kept.lastIndex
        }
        return kept
    }

    private fun rebuild(kept: List<Kept>): ObservationNode {
        if (kept.isEmpty()) {
            return ObservationNode(type = "root")
        }
        val children = List(kept.size) { mutableListOf<Int>() }
        for ((index, item) in kept.withIndex()) {
            if (item.parent >= 0) {
                children[item.parent] += index
            }
        }
        fun build(index: Int): ObservationNode {
            val node = kept[index].node
            val kids = children[index]
            return if (kids.isEmpty()) node else node.copy(children = kids.map(::build))
        }
        return build(0)
    }

    private fun isSecret(node: ObservationNode): Boolean {
        val haystack = listOf(node.id, node.description, node.text, node.type)
            .joinToString(" ")
        return SECRET_FIELD.containsMatchIn(haystack)
    }

    private fun redact(value: String): String {
        if (value.isEmpty()) {
            return value
        }
        var text = EMAIL.replace(value, "[email]")
        text = CARD.replace(text, "[card]")
        text = PHONE.replace(text, "[phone]")
        if (OTP_HINT.containsMatchIn(value)) {
            text = OTP.replace(text, "[otp]")
        }
        return text
    }

    private data class Item(
        val node: ObservationNode,
        val parent: Int,
        val dropped: Boolean,
    )

    private data class Kept(
        val parent: Int,
        val node: ObservationNode,
    )

    private companion object {
        val EMAIL = Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        val CARD = Regex("\\b(?:\\d[ -]?){13,19}\\b")
        val PHONE = Regex("\\+?\\d[\\d ()-]{7,}\\d")
        val OTP = Regex("\\b\\d{4,8}\\b")
        val OTP_HINT = Regex("(?i)code|otp|verification|passcode|\\u043a\\u043e\\u0434")
        val SECRET_FIELD = Regex(
            "(?i)password|passwd|passcode|one[- ]?time|\\botp\\b|verification code|\\bpin\\b",
        )
    }
}
