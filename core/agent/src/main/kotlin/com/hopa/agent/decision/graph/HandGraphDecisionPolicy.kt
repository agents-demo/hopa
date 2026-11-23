package com.hopa.agent.decision.graph

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.contracts.error.HopaError
import com.hopa.decision.graph.GraphStepSource

/**
 * The navigation graph as a step policy.
 *
 * It takes the same input as a language model and answers with the same three
 * things: an action, a question or a final answer. One edge per pass; the node
 * is re-derived from the screen it actually sees, so a graph can never walk
 * further than the phone went.
 */
class HandGraphDecisionPolicy(
    private val source: GraphStepSource,
) : DecisionPolicy {
    override val name: String = "anchors"

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        val screen = input.observation ?: return DecisionOutcome(Decision.NoPath)
        val step = runCatching { source.next(screen, input.context.goal) }.getOrNull()
            ?: return DecisionOutcome(Decision.NoPath)
        return DecisionOutcome(
            Decision.Act(
                action = step.action,
                then = if (step.done) step.answer.ifBlank { "Done." } else null,
            ),
        )
    }
}

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
