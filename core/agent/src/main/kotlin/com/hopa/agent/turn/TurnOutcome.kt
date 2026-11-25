package com.hopa.agent.turn

import com.hopa.agent.goal.GoalVerification
import com.hopa.contracts.error.HopaError
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.RunRecord

/**
 * What one turn produced. The caller turns this into bubbles, receipts and
 * storage; the runner never writes to a conversation and never posts a
 * notification.
 */
data class TurnOutcome(
    val source: TurnSource,
    val answer: String = "",
    val records: List<RunRecord> = emptyList(),
    val narration: List<String> = emptyList(),
    val options: List<String> = emptyList(),
    val error: HopaError? = null,
    val usage: ModelUsage = ModelUsage(),
    val surfaceName: String = "",
    val surfaceError: String = "",
    /** Steps the person is asked to approve; empty unless [source] is PLAN. */
    val pendingPlan: List<String> = emptyList(),
    /** Present only when the request carried checkpoints. */
    val checkpoints: GoalVerification? = null,
    /** The screen the turn ended on, when a step or replay observed one. */
    val finalScreen: Observation? = null,
    /** What the replay did, step by step; empty unless [source] is RECIPE. */
    val replaySteps: List<String> = emptyList(),
    /** True when this turn's steps were stored as a recipe for next time. */
    val recipeSaved: Boolean = false,
    /**
     * The knowledge bundle this turn routed with. Two runs are only comparable
     * when both name it, so the receipt carries it. Empty when nothing acted.
     */
    val knowledgeVersion: String = "",
    /**
     * What the model read: `uia-tree` when the step loop asked a model over the
     * accessibility tree, empty when no model answered. The receipt names it so
     * "model" on Windows is not mistaken for a screenshot-only or trained-tree
     * mode.
     */
    val modelInput: String = "",
    val millis: Long = 0,
) {
    val executed: Int get() = records.count { it.executed }

    val verified: Int get() = records.count { it.verified }

    /** No error and no question: the turn finished on its own terms. */
    val clean: Boolean get() = error == null && options.isEmpty()
}
