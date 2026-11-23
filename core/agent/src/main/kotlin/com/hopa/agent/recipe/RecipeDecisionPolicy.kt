package com.hopa.agent.recipe

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.observation.tree.NodeAnchor

/**
 * A stored recipe as a step policy: one recorded action per pass.
 *
 * The ref of a step is re-resolved through the anchor saved with it, so a
 * redrawn tree still finds the same control. A step whose anchor is gone, or a
 * screen that cannot be read, says [Decision.NoPath] and the turn falls through
 * to the next rung - a replay never guesses a tap.
 */
class RecipeDecisionPolicy(
    private val recipe: Recipe,
) : DecisionPolicy {
    override val name: String = "recipe"

    private var index: Int = 0

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        val screen = input.observation ?: return DecisionOutcome(Decision.NoPath, policy = name)
        if (!recipe.replayable || index !in recipe.steps.indices) {
            return DecisionOutcome(Decision.NoPath, policy = name)
        }
        val step = recipe.steps[index]
        val anchored = if (step.ref.isNullOrBlank()) {
            step
        } else {
            val ref = NodeAnchor.refOf(screen.tree, recipe.anchorAt(index))
                ?: return DecisionOutcome(Decision.NoPath, policy = name)
            step.copy(ref = ref)
        }
        val last = index == recipe.steps.lastIndex
        index += 1
        return DecisionOutcome(
            Decision.Act(anchored, then = if (last) sentence() else null),
            policy = name,
        )
    }

    private fun sentence(): String {
        val count = recipe.steps.size
        val steps = if (count == 1) "step" else "steps"
        return "Repeated the $count $steps that worked last time."
    }
}
