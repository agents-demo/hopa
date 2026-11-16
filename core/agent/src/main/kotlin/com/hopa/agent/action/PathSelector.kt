package com.hopa.agent.action

import com.hopa.contracts.wire.Action

/**
 * Chooses the cheapest reliable path for an action **before** the gate classifies
 * and executes it. Implementations are pure: no device calls, no I/O. The
 * executor records the chosen tier on the step.
 */
interface PathSelector {
    fun choose(action: Action): PlannedAction
}
