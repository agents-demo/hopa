package com.hopa.agent.turn

/** How the turn was answered, and therefore what the receipt can claim. */
enum class TurnSource {
    /** A stored recipe ran; no plan, no loop, at most one cheap model call. */
    RECIPE,

    /** The step loop ran, with the model choosing each step. */
    MODEL,

    /** The plan gate answered; nothing was tapped and the person decides next. */
    PLAN,

    /** A canonical command ran without asking a model. */
    COMMAND,

    /** A hand-written graph for a known app ran the steps. */
    GRAPH,

    /** The on-device tree ranker chose at least one step. */
    TREE,

    /** No surface could see the screen, so the turn did not start. */
    UNAVAILABLE,
}
