package com.hopa.agent.decision.graph

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
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
        val screen = input.observation ?: return DecisionOutcome(Decision.NoPath, policy = name)
        val step = runCatching { source.next(screen, input.context.goal) }.getOrNull()
            ?: return DecisionOutcome(Decision.NoPath, policy = name)
        return DecisionOutcome(
            Decision.Act(
                action = step.action,
                then = if (step.done) step.answer.ifBlank { "Done." } else null,
            ),
        )
    }
}
