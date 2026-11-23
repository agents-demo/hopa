package com.hopa.agent.decision.graph

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.contracts.error.HopaError

/** Answer without asking anyone: the last rung, when nothing else may speak. */
class SayDecisionPolicy(
    private val answer: String,
    private val error: HopaError? = null,
) : DecisionPolicy {
    override val name: String = "say"

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        return DecisionOutcome(Decision.Say(answer, error))
    }
}
