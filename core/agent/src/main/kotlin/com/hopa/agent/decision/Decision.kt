package com.hopa.agent.decision

import com.hopa.contracts.error.HopaError
import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.Observation

/**
 * What the loop may do next. A model, a navigation graph or a rule layer all
 * answer with this, so the loop never learns which one spoke.
 */
sealed interface Decision {
    /** Do one action on the screen. */
    data class Act(
        val action: Action,
        /**
         * When set, this action finishes the goal: the loop executes it and then
         * ends the turn with this answer. A graph's last edge uses it.
         */
        val then: String? = null,
    ) : Decision

    /** Stop and ask the person, with the options the layer offers. */
    data class Ask(val answer: String, val options: List<String> = emptyList()) : Decision

    /** Answer in plain text and finish the turn. */
    data class Say(
        val answer: String,
        /** Set when the turn ends because something is missing, not because it is done. */
        val error: HopaError? = null,
    ) : Decision

    /** This layer knows no safe next step here; the caller decides what to do. */
    data object NoPath : Decision

    /** The layer could not produce a decision; the message is the error. */
    data class Failed(val error: HopaError) : Decision
}

/**
 * Everything a decision needs for one step. The screen is the observation, not
 * a rendered prompt: a policy that never calls a model should not pay for text.
 */
data class DecisionInput(
    val context: TurnContext,
    val observation: Observation?,
    val step: Int,
    /** Plain notes from earlier steps: what each action did. */
    val notes: List<ModelMessage> = emptyList(),
    val webAvailable: Boolean = false,
    /** True for the last call after the step limit: answer, do not act. */
    val atStepLimit: Boolean = false,
    /** Base64 JPEG of the screen, when the client can take one. */
    val screenshot: String? = null,
)

data class DecisionOutcome(
    val decision: Decision,
    /** Tokens a model spent; zero for a graph or a rule layer. */
    val usage: ModelUsage = ModelUsage(),
    /**
     * The reply as the policy produced it, when it has one. The loop keeps it in
     * the notes so a model still sees its own earlier steps.
     */
    val raw: String? = null,
    /** Which policy spoke, so the receipt can name the path that ran. */
    val policy: String? = null,
)

/**
 * The seam between the loop and whatever decides. Implementations:
 *
 *  - ModelDecisionPolicy builds the prompt, asks the provider and parses the reply.
 *  - a graph policy picks an edge from the screen it sees.
 *  - a fallback policy tries one and then the other.
 */
interface DecisionPolicy {
    val name: String

    suspend fun decide(input: DecisionInput): DecisionOutcome
}
