package com.hopa.agent.decision.command

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.decision.classifier.IntentClassifier

/**
 * A canonical command as a step policy: "open settings", "back", "scroll".
 *
 * It answers with one action and its sentence, so the loop executes and reports
 * it exactly like any other step. A goal the classifier is not sure about is
 * [Decision.NoPath] and the next rung answers.
 */
class CommandDecisionPolicy(
    private val classifier: IntentClassifier,
) : DecisionPolicy {
    override val name: String = "command"

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        val match = runCatching {
            classifier.classify(input.context.goal, input.context.installedApps)
        }.getOrNull() ?: return DecisionOutcome(Decision.NoPath, policy = name)
        return DecisionOutcome(
            Decision.Act(match.intent.action, then = match.intent.answer),
            policy = name,
        )
    }
}
