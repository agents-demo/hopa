package com.hopa.agent.decision.tree

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.contracts.model.ActionScorer
import com.hopa.contracts.wire.Action
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Locale
import kotlin.math.exp

/**
 * The tree rung: read the screen, score the candidate actions, act only on a
 * clear winner.
 *
 * This is the second path in the turn picture (graph, then the tree model, then
 * a small local model, then the API). It is a ranker, not a planner: it can pick
 * one visible control, scroll, go back or go home. It cannot open an app it does
 * not see and it cannot answer a question, so every other outcome is
 * [Decision.NoPath] and the chain moves on.
 *
 * Safety, because a cross-encoder trained on AndroidControl is not a validated
 * controller:
 *  - it starts after the first step and runs for at most [lastStep], then hands
 *    over to the model, so the target app has a chance to open first;
 *  - it never picks a label that names a destructive or sending action;
 *  - it needs both a minimum probability and a margin over the runner-up;
 *  - the model file is optional, so a phone without it simply has no rung.
 */
class TreeRankerDecisionPolicy(
    private val scorer: suspend () -> ActionScorer?,
    private val enabled: suspend () -> Boolean = { true },
    private val minProbability: Double = 0.30,
    private val minMargin: Double = 0.10,
    /** The first step is left to the graph/command/model so the target app can open. */
    private val firstStep: Int = 1,
    /** The last step this rung may answer; later steps go to the model. */
    private val lastStep: Int = 3,
    private val budgetMillis: Long = 8_000,
    /** One line per call, for logcat and the run's diagnostics; no screen text. */
    private val onOutcome: (String) -> Unit = {},
) : DecisionPolicy {

    override val name: String = "tree"

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        if (input.atStepLimit || input.step < firstStep || input.step > lastStep) {
            return DecisionOutcome(Decision.NoPath)
        }
        if (!runCatching { enabled() }.getOrDefault(false)) return DecisionOutcome(Decision.NoPath)
        val observation = input.observation ?: return DecisionOutcome(Decision.NoPath)

        val candidates = TreeCandidates.build(input.context.goal, observation)
        if (candidates.size < 2) return DecisionOutcome(Decision.NoPath)
        val summary = TreeCandidates.summary(observation)
        val labels = candidates.map { it.label }

        // Loading a 140M-parameter session can take a second on a phone; keep
        // both the load and the score off the caller's thread and under a cap.
        val scores = withTimeoutOrNull(budgetMillis) {
            withContext(Dispatchers.Default) {
                val engine = runCatching { scorer() }.getOrNull()
                if (engine == null) {
                    null
                } else {
                    runCatching { engine.score(input.context.goal, summary, labels) }.getOrNull()
                }
            }
        } ?: return DecisionOutcome(Decision.NoPath)
        if (scores.size < candidates.size) return DecisionOutcome(Decision.NoPath)

        val probabilities = softmax(scores.copyOf(candidates.size))
        var best = 0
        for (index in probabilities.indices) {
            if (probabilities[index] > probabilities[best]) best = index
        }
        var runnerUp = 0.0
        for (index in probabilities.indices) {
            if (index != best) runnerUp = maxOf(runnerUp, probabilities[index].toDouble())
        }
        val winner = probabilities[best].toDouble()
        if (winner < minProbability || winner - runnerUp.coerceAtLeast(0.0) < minMargin) {
            onOutcome("skip: best=${labels[best]} p=${format(winner)} margin=${format(winner - runnerUp)}")
            return DecisionOutcome(Decision.NoPath)
        }

        val chosen = candidates[best]
        if (isRisky(chosen)) {
            onOutcome("skip risky: ${chosen.label}")
            return DecisionOutcome(Decision.NoPath)
        }
        if (chosen.kind == TreeCandidate.Kind.TYPE && !wantsTyping(input.context.goal)) {
            onOutcome("skip: no typing in this goal (${chosen.label})")
            return DecisionOutcome(Decision.NoPath)
        }
        val action = actionFor(chosen) ?: run {
            onOutcome("skip: ${chosen.label} is not an action")
            return DecisionOutcome(Decision.NoPath)
        }
        if (action.kind == "ui.type" && action.text.isNullOrBlank()) return DecisionOutcome(Decision.NoPath)
        onOutcome("act: ${chosen.label} p=${format(winner)} margin=${format(winner - runnerUp)}")
        return DecisionOutcome(decision = Decision.Act(action), policy = name)
    }

    private fun actionFor(candidate: TreeCandidate): Action? = when (candidate.kind) {
        TreeCandidate.Kind.TAP -> Action(
            kind = "ui.tap",
            ref = candidate.ref,
            x = candidate.x.takeIf { it > 0 },
            y = candidate.y.takeIf { it > 0 },
        )
        TreeCandidate.Kind.TYPE -> Action(
            kind = "ui.type",
            ref = candidate.ref,
            text = candidate.text,
        )
        TreeCandidate.Kind.SCROLL -> Action(kind = "ui.scroll", direction = "down")
        TreeCandidate.Kind.BACK -> Action(kind = "ui.back")
        TreeCandidate.Kind.HOME -> Action(kind = "ui.home")
        // The ranker may notice the goal is reached, but only the model (or a
        // verified checkpoint) is allowed to end the turn. Falling through to
        // the model here is safer than a bare "done" from a cross-encoder.
        TreeCandidate.Kind.DONE -> null
    }

    /**
     * A candidate whose words name an irreversible or outgoing action is left to
     * the model, where the approval gate can see a sentence, not a score.
     */
    private fun isRisky(candidate: TreeCandidate): Boolean {
        val text = "${candidate.label} ${candidate.screenLabel}".lowercase(Locale.US)
        return RISKY.any { text.contains(it) }
    }

    /** Text entry is only allowed when the goal asks for words, not on any screen. */
    private fun wantsTyping(goal: String): Boolean {
        val lower = goal.lowercase(Locale.US)
        return TYPING.any { lower.contains(it) }
    }

    private fun softmax(logits: FloatArray): FloatArray {
        if (logits.isEmpty()) return floatArrayOf()
        var max = logits[0]
        for (value in logits) if (value > max) max = value
        val out = FloatArray(logits.size)
        var sum = 0.0
        for (index in logits.indices) {
            val e = exp((logits[index] - max).toDouble())
            out[index] = e.toFloat()
            sum += e
        }
        if (sum > 0.0) {
            for (index in out.indices) out[index] = (out[index] / sum).toFloat()
        }
        return out
    }

    private fun format(value: Double): String = String.format(Locale.US, "%.2f", value)

    private companion object {
        val RISKY = listOf(
            "send", "delete", "remove", "erase", "reset", "uninstall", "format",
            "buy", "pay", "purchase", "checkout", "confirm", "authorize",
            "call", "dial", "share", "post", "publish", "block", "report",
        )
        val TYPING = listOf(
            "type ", "enter ", "search ", "search for", "write ", "fill ",
            "message", "text ", "say ", "send ",
        )
    }
}
