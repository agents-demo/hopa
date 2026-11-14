package com.hopa.core.validation

import com.hopa.core.contracts.ActionKind
import com.hopa.core.contracts.Decision
import com.hopa.core.contracts.ErrorCodes

object DecisionRules {
    fun validate(decision: Decision): ValidationResult {
        val action = decision.action
        if (decision.done && action != null) {
            return ValidationResult.fail(
                ErrorCodes.SCHEMA,
                "done=true cannot carry an action",
            )
        }
        if (decision.needUser && decision.options.isNullOrEmpty()) {
            return ValidationResult.fail(
                ErrorCodes.SCHEMA,
                "needUser=true requires options",
            )
        }
        if (action != null && ActionKind.fromWire(action.kind) == null) {
            return ValidationResult.fail(
                ErrorCodes.SCHEMA,
                "unknown action kind: ${action.kind}",
            )
        }
        return ValidationResult.ok()
    }
}
