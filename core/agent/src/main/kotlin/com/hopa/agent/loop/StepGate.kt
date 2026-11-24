package com.hopa.agent.loop

/** What a step hook asks the loop to do before the next decision. */
enum class StepGate {
    /** No takeover; continue with the current observation. */
    Proceed,

    /** A takeover finished: re-observe before deciding the next step. */
    Refresh,

    /** The takeover was cancelled; stop instead of claiming success. */
    Stop,
}
