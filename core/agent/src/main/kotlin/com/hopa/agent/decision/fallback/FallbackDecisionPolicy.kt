package com.hopa.agent.decision.fallback

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The local model, with one agreed escape hatch.
 *
 * A chain stops at the first policy that does not say "no path", so a provider
 * error would end the turn before the API could answer. With consent, a failed
 * local step becomes "no path" and the next policy (the API) gets the same
 * input. Without consent the failure is returned unchanged: a local turn must
 * never become a cloud turn on its own.
 *
 * A local call gets its own budget. The whole turn already has a deadline; if
 * the local model could spend all of it, the API would never run.
 */
class FallbackDecisionPolicy(
    private val primary: DecisionPolicy,
    private val hasFallback: Boolean,
    private val primaryBudgetMillis: Long = 0,
) : DecisionPolicy {
    override val name: String = primary.name

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        if (!hasFallback) {
            return primary.decide(input)
        }
        val outcome = if (primaryBudgetMillis > 0) {
            withTimeoutOrNull(primaryBudgetMillis) { primary.decide(input) }
                ?: return DecisionOutcome(Decision.NoPath)
        } else {
            primary.decide(input)
        }
        return if (outcome.decision is Decision.Failed) {
            DecisionOutcome(Decision.NoPath, outcome.usage)
        } else {
            outcome
        }
    }
}
