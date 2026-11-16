package com.hopa.agent.action

import com.hopa.contracts.wire.Action

/** An action plus the path the selector chose for it. */
data class PlannedAction(
    val action: Action,
    val tier: PathTier,
)
