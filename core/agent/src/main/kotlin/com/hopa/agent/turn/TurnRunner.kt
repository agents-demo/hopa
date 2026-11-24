package com.hopa.agent.turn

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.agent.decision.DecisionRuntime
import com.hopa.agent.decision.StepPolicy
import com.hopa.agent.decision.command.CommandDecisionPolicy
import com.hopa.agent.decision.graph.ChainDecisionPolicy
import com.hopa.agent.decision.graph.HandGraphDecisionPolicy
import com.hopa.agent.decision.graph.SayDecisionPolicy
import com.hopa.agent.decision.model.ModelDecisionPolicy
import com.hopa.agent.goal.GoalVerification
import com.hopa.agent.goal.GoalVerifier
import com.hopa.agent.loop.AgentLoop
import com.hopa.agent.loop.StepGate
import com.hopa.agent.plan.PlanSource
import com.hopa.agent.recipe.RecipeDecisionPolicy
import com.hopa.agent.recipe.RecipeStore
import com.hopa.catalog.store.CatalogSnapshot
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.error.HopaError
import com.hopa.contracts.ports.Clock
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.turn.TurnResult
import com.hopa.decision.classifier.IntentClassifier
import com.hopa.decision.graph.GraphStepSource
import com.hopa.runlog.store.RunRecorder
import kotlinx.coroutines.withTimeoutOrNull

/**
 * One goal, one turn, one path - for every client.
 *
 * The order is the one the app has always used, now written once:
 *
 *  1. an unapproved goal under plan-first is answered with a plan, nothing runs;
 *  2. a surface that cannot see the screen stops the turn honestly;
 *  3. a stored recipe runs cheaply, and answers from its final screen;
 *  4. otherwise the step loop runs under one deadline for the whole turn;
 *  5. the final screen is checked against the person's checkpoints;
 *  6. a recipe is saved only when the turn was clean, verified and reachable.
 *
 * Clients supply the ports and then decide what to do with the outcome: bubbles,
 * receipts, notifications. This class touches no storage, no Android and no
 * conversation.
 */
class TurnRunner(
    private val steps: StepPolicy,
    /** The API model, used only when the request allows cloud fallback. */
    private val fallbackSteps: StepPolicy? = null,
    private val executorFor: (DevicePort) -> ActionExecutor,
    private val recorder: RunRecorder,
    private val clock: Clock,
    private val recipes: RecipeStore? = null,
    private val plans: PlanSource? = null,
    private val verifier: GoalVerifier = GoalVerifier(),
    /** The tables this client uses; read per turn, so an update applies next time. */
    private val knowledge: () -> CatalogSnapshot,
    /** Decision layers; null in a client that has none registered. */
    private val decisions: DecisionRuntime? = null,
    /** Canonical commands that need no model; null disables the fast path. */
    private val commands: IntentClassifier? = null,
    /** Hand-written known-app graphs; null disables the path. */
    private val graphs: GraphStepSource? = null,
) {
    suspend fun run(
        request: TurnRequest,
        beforeStep: suspend () -> StepGate = { StepGate.Proceed },
        isCancelled: () -> Boolean = { false },
    ): TurnOutcome {
        val started = clock.nowMillis()
        // Read once per turn: an accepted bundle applies to the next turn, and the
        // receipt must name the one this turn actually routed with.
        val tables = knowledge()

        if (!request.surfaceAvailable) {
            return TurnOutcome(
                source = TurnSource.UNAVAILABLE,
                error = HopaError(
                    ErrorCodes.DEVICE,
                    request.surfaceError.ifBlank { "no screen answered" },
                ),
                surfaceName = request.surfaceName,
                surfaceError = request.surfaceError,
                millis = clock.nowMillis() - started,
            )
        }
        val known = if (request.useGraphs) {
            runCatching { graphs?.target(request.goal) }.getOrNull()
        } else {
            null
        }
        val graphOnly = request.useGraphs && graphs != null && !request.graphFallback

        // The loop decides every step. These only choose which rungs it gets:
        // the graph, a canonical command, the model, and the API last when the
        // person allowed it. A graph-only turn ends with the refusal.
        val model = ModelDecisionPolicy(steps = steps, knowledge = { tables })
        val cloud = fallbackSteps
            ?.takeIf { request.cloudFallback }
            ?.let { ModelDecisionPolicy(steps = it, knowledge = { tables }) }
        val graph = if (request.useGraphs && graphs != null) {
            HandGraphDecisionPolicy(graphs)
        } else {
            null
        }
        val command = commands
            ?.takeIf { request.instantCommands }
            ?.let { CommandDecisionPolicy(it) }
        // The plan gate comes before any of this: it needs no screen.
        // A canonical command needs no plan: asking a model to write steps for
        // "open settings" is slower and less predictable than opening it. The
        // policy runs it inside the loop; this only skips the plan gate.
        val commandCanAnswer = commands?.let { classifier ->
            request.instantCommands &&
                runCatching { classifier.classify(request.goal, request.installedApps) }
                    .getOrNull() != null
        } == true
        // A goal a graph covers needs no plan: its steps are written already.
        if (!graphOnly && request.planFirst && !request.planApproved && known == null && !commandCanAnswer) {
            return plan(request, started)
        }

        // A stored recipe is the first rung: its steps already worked once. It
        // asks the same loop for one recorded action per pass and gives up
        // quietly when an anchor is gone.
        val recipe = if (!graphOnly && request.replay) {
            runCatching { recipes?.find(request.goal) }.getOrNull()
                ?.takeIf { it.replayable }
                ?.takeIf { stored ->
                    stored.app.isBlank() ||
                        request.installedApps.any { it.packageName.equals(stored.app, ignoreCase = true) }
                }
                ?.let { RecipeDecisionPolicy(it) }
        } else {
            null
        }
        val policy = when {
            graphOnly -> ChainDecisionPolicy(
                listOfNotNull(
                    graph,
                    SayDecisionPolicy(
                        answer = GRAPH_ONLY_ANSWER,
                        error = HopaError(ErrorCodes.BLOCKED, "no graph for this goal"),
                    ),
                ),
            )
            else -> ChainDecisionPolicy(listOfNotNull(recipe, graph, command, model, cloud))
        }
        return fromModel(request, started, isCancelled, tables, policy, graph != null, beforeStep)
    }

/** Answers with the steps to approve; the person's yes sends a new request. */
    private suspend fun plan(request: TurnRequest, started: Long): TurnOutcome {
        val steps = plans
            ?.let { source -> runCatching { source.plan(request.goal) }.getOrDefault(emptyList()) }
            .orEmpty()
        return TurnOutcome(
            source = TurnSource.PLAN,
            pendingPlan = steps,
            error = if (steps.isEmpty()) HopaError(ErrorCodes.MODEL, "No plan came back") else null,
            surfaceName = request.surfaceName,
            millis = clock.nowMillis() - started,
        )
    }

    private suspend fun fromModel(
        request: TurnRequest,
        started: Long,
        isCancelled: () -> Boolean,
        tables: CatalogSnapshot,
        policy: DecisionPolicy,
        graphInChain: Boolean = false,
        beforeStep: suspend () -> StepGate = { StepGate.Proceed },
    ): TurnOutcome {
        val loop = AgentLoop(
            policy = policy,
            device = request.device,
            executor = executorFor(request.device),
            recorder = recorder,
            clock = clock,
            webAvailable = request.webAvailable,
            knowledge = tables,
            decisions = decisions,
        )
        val result = withTimeoutOrNull(request.timeoutMillis) {
            loop.run(
                runId = request.runId,
                traceId = request.traceId,
                context = TurnContext(
                    goal = request.goal,
                    history = request.history,
                    memory = request.memory,
                    skills = request.skills,
                    installedApps = request.installedApps,
                    platform = request.platform,
                    vision = request.vision,
                    appFunctions = request.appFunctions,
                    phoneAccess = request.phoneAccess,
                ),
                isCancelled = isCancelled,
                beforeStep = beforeStep,
            )
        }

        if (result == null) {
            return TurnOutcome(
                source = sourceOf(graphInChain, emptySet()),
                knowledgeVersion = tables.version,
                answer = stoppedAfter(request.timeoutMillis),
                error = HopaError(ErrorCodes.TIMEOUT, "the turn ran out of time"),
                surfaceName = request.surfaceName,
                millis = clock.nowMillis() - started,
            )
        }

        // The loop returns no screen, so a turn with checkpoints reads the final
        // one itself. That is the only extra observation, and only when asked.
        val screen = if (request.checkpoints.isEmpty()) {
            null
        } else {
            runCatching { request.device.observe() }.getOrNull()
        }
        val verification = if (request.checkpoints.isEmpty()) {
            null
        } else {
            verifier.verify(screen, request.checkpoints)
        }

        val source = sourceOf(graphInChain, result.sources)
        return TurnOutcome(
            source = source,
            knowledgeVersion = tables.version,
            answer = result.answer,
            records = result.records,
            narration = result.narration,
            options = result.options,
            error = result.error,
            usage = result.usage,
            surfaceName = request.surfaceName,
            checkpoints = verification,
            finalScreen = screen,
            // The recipe is a policy now, but its receipt still lists the steps
            // it replayed, exactly as the old fast path did.
            replaySteps = if (source == TurnSource.RECIPE) {
                result.records.mapIndexed { index, record -> "${index + 1}. ${record.action.kind}" }
            } else {
                emptyList()
            },
            recipeSaved = saveRecipe(request, result, verification),
            millis = clock.nowMillis() - started,
        )
    }

    /**
     * A recipe is worth storing only when the next replay could trust it: the
     * turn finished cleanly, something verified, the person's checkpoints hold,
     * and every step that names a ref recorded what that ref pointed at.
     */
    private suspend fun saveRecipe(
        request: TurnRequest,
        result: TurnResult,
        verification: GoalVerification?,
    ): Boolean {
        val store = recipes ?: return false
        if (result.error != null || result.options.isNotEmpty()) {
            return false
        }
        if (result.records.isEmpty() || result.records.none { it.verified }) {
            return false
        }
        if (verification?.complete == false) {
            return false
        }
        if (result.records.any { !it.action.ref.isNullOrBlank() && it.targetKey.isNullOrBlank() }) {
            return false
        }
        return runCatching {
            store.save(
                goal = request.goal,
                steps = result.records.map { it.action },
                anchors = result.records.map { it.targetKey.orEmpty() },
                screenHash = result.records.first().beforeHash.orEmpty(),
                endHash = result.records.last().afterHash.orEmpty(),
            )
        }.isSuccess
    }

    private fun stoppedAfter(timeoutMillis: Long): String = if (timeoutMillis >= 60_000) {
        "I stopped after ${timeoutMillis / 60_000} minutes."
    } else {
        "I stopped after ${timeoutMillis / 1_000} seconds."
    }

    private companion object {
        /**
         * A graph step spends no tokens, so a turn that never asked a model is a
         * graph turn: the receipt can say Graph without a per-step source.
         */
        /**
         * The path the receipt may name: a model rung outranks a command, a
         * command outranks anchors, and anchors outranks the refusal sentence.
         */
        fun sourceOf(graphInChain: Boolean, sources: Set<String>): TurnSource = when {
            "recipe" in sources -> TurnSource.RECIPE
            "model" in sources -> TurnSource.MODEL
            "command" in sources -> TurnSource.COMMAND
            "anchors" in sources -> TurnSource.GRAPH
            sources.isEmpty() && graphInChain -> TurnSource.GRAPH
            sources.isEmpty() -> TurnSource.MODEL
            else -> TurnSource.GRAPH
        }

        const val GRAPH_ONLY_ANSWER =
            "I only have graphs for a few apps. Switch Steps to Auto or Model for this goal."
    }
}
