package com.hopa.agent.decision.tree

/**
 * One candidate action the ranker may choose.
 *
 * [label] is what the model scores (`click Settings`, `type Search: …`); the
 * ref and the centre are here only so the policy can turn the winner back into
 * an [com.hopa.contracts.wire.Action]. The model never sees either.
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
