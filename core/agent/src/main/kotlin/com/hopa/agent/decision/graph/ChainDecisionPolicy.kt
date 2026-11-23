package com.hopa.agent.decision.graph

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy

/**
 * Try each policy in order and take the first that is not [Decision.NoPath].
 *
 * This is the whole ladder: a graph, then a smaller model, then a bigger one.
 * A policy that fails outright stops the chain - only "I do not know this
 * screen" moves on.
 */
class ChainDecisionPolicy(
    private val policies: List<DecisionPolicy>,
) : DecisionPolicy {
    override val name: String = policies.joinToString("/") { it.name }

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        var last: DecisionOutcome? = null
        for (policy in policies) {
            val outcome = policy.decide(input)
            if (outcome.decision !is Decision.NoPath) {
                return outcome
            }
            last = outcome
        }
        return last ?: DecisionOutcome(Decision.NoPath)
    }
}
