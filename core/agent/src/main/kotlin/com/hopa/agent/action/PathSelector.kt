package com.hopa.agent.action

import com.hopa.contracts.wire.Action

/**
 * Chooses the cheapest reliable path for an action **before** the gate classifies
 * and executes it. Implementations are pure: no device calls, no I/O. The
 * executor records the chosen tier on the step.
 */
interface PathSelector {
    fun choose(action: Action): PlannedAction

    /**
     * All viable paths for one action, cheapest first. The executor tries them in
     * order when a tier is unavailable, so an intent can fall through to a UIA
     * launch without the caller asking twice. The default keeps a selector that
     * only implements [choose] single-path; a fallback is always visible because
     * the executor logs every tier it leaves.
     */
    fun plan(action: Action): List<PlannedAction> = listOf(choose(action))
}
