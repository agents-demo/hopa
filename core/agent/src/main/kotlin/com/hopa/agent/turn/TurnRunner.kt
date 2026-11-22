package com.hopa.agent.turn

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.decision.DecisionRuntime
import com.hopa.agent.decision.StepPolicy
import com.hopa.agent.goal.GoalVerification
import com.hopa.agent.goal.GoalVerifier
import com.hopa.agent.loop.AgentLoop
import com.hopa.agent.loop.RunNarrator
import com.hopa.agent.plan.PlanSource
import com.hopa.agent.recipe.Recipe
import com.hopa.agent.recipe.RecipeStore
import com.hopa.agent.recipe.ReplayAnswer
import com.hopa.agent.recipe.Replayer
import com.hopa.catalog.store.CatalogSnapshot
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.error.HopaError
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.ports.Clock
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.turn.TurnResult
import com.hopa.contracts.wire.RunRecord
import com.hopa.decision.ActionSignature
import com.hopa.decision.classifier.IntentClassifier
import com.hopa.decision.graph.GraphStepSource
import com.hopa.runlog.store.RunRecorder
import kotlinx.coroutines.delay
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
    private val executorFor: (DevicePort) -> ActionExecutor,
    private val recorder: RunRecorder,
    private val clock: Clock,
    private val recipes: RecipeStore? = null,
    private val replayAnswer: ReplayAnswer? = null,
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
    /** How long the screen gets between replayed steps; a test passes a no-op. */
    private val settle: suspend (Long) -> Unit = { delay(it) },
) {
    suspend fun run(request: TurnRequest, isCancelled: () -> Boolean = { false }): TurnOutcome {
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
        // Graph only: the person asked for graphs, so neither a command
        // nor the model may answer in their place.
        if (request.useGraphs && graphs != null && !request.graphFallback) {
            graph(request, started, tables, isCancelled)?.let { return it }
            return TurnOutcome(
                source = TurnSource.GRAPH,
                answer = "I only have graphs for a few apps. " +
                    "Switch Steps to Auto or Model for this goal.",
                error = HopaError(ErrorCodes.BLOCKED, "no graph for this goal"),
                surfaceName = request.surfaceName,
                millis = clock.nowMillis() - started,
            )
        }
        // A goal the graph can finish goes first: its steps are written, its
        // receipt says Graph, and no model is asked for something already known.
        val graphFirst = known?.completes == true
        if (!graphFirst && request.instantCommands && commands != null) {
            command(request, started, tables)?.let { return it }
        }
        if (request.useGraphs && graphs != null) {
            graph(request, started, tables, isCancelled)?.let { return it }
        }
        if (graphFirst && request.instantCommands && commands != null) {
            command(request, started, tables)?.let { return it }
        }
        // A canonical command needs no plan: asking a model to write steps for
        // "open settings" is slower and less predictable than opening it. The
        // path still falls through to the plan gate on any doubt.
        if (request.planFirst && !request.planApproved) {
            return plan(request, started)
        }
        if (request.replay) {
            val recipe = runCatching { recipes?.find(request.goal) }.getOrNull()
            if (recipe != null) {
                replay(recipe, request, started, tables)?.let { return it }
            }
        }
        return fromModel(request, started, isCancelled, tables)
    }

    /**
     * A canonical command, executed without a model.
     *
     * The classifier returns null for anything it is not sure about, and so
     * does this path when the screen cannot be read or the step throws: the
     * model then handles the turn exactly as before. One step, one record, no
     * tokens, and the answer names what happened.
     */
    private suspend fun command(request: TurnRequest, started: Long, tables: CatalogSnapshot): TurnOutcome? {
        val classifier = commands ?: return null
        val match = runCatching { classifier.classify(request.goal, request.installedApps) }
            .getOrNull() ?: return null
        val before = runCatching { request.device.observe() }.getOrNull() ?: return null
        val result = runCatching {
            executorFor(request.device).execute(
                runId = request.runId,
                step = 0,
                traceId = request.traceId,
                action = match.intent.action,
                before = before,
            )
        }.getOrNull() ?: return null
        val error = result.record.error
        return TurnOutcome(
            source = TurnSource.COMMAND,
            knowledgeVersion = tables.version,
            answer = match.intent.answer,
            records = listOf(result.record),
            narration = RunNarrator.lines(listOf(result.record)),
            error = if (result.record.executed && error.isNullOrBlank()) {
                null
            } else {
                HopaError(ErrorCodes.BLOCKED, error ?: "the step did not run")
            },
            surfaceName = request.surfaceName,
            millis = clock.nowMillis() - started,
        )
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

    /** Null when the recipe did not run to the end; the caller uses the model. */
    private suspend fun replay(
        recipe: Recipe,
        request: TurnRequest,
        started: Long,
        tables: CatalogSnapshot,
    ): TurnOutcome? {
        val installed = request.installedApps.map { it.packageName }
        val outcome = runCatching {
            Replayer(
                executorFor = executorFor,
                installedApps = { installed },
                settle = settle,
            ).replay(recipe, request.device)
        }.getOrNull() ?: return null
        if (!outcome.trustworthy) {
            return null
        }

        // The recipe knows the taps, not the words: one cheap call reads the
        // final screen, so the person gets an answer and not a step count.
        val spoken = outcome.screen?.let { screen ->
            replayAnswer?.let { answer ->
                runCatching { answer.answer(request.goal, screen) }.getOrNull()
            }
        }
        return TurnOutcome(
            source = TurnSource.RECIPE,
            knowledgeVersion = tables.version,
            answer = spoken?.first ?: "Repeated the ${outcome.done} steps that worked last time.",
            usage = ModelUsage(totalTokens = spoken?.second ?: 0),
            surfaceName = request.surfaceName,
            finalScreen = outcome.screen,
            replaySteps = recipe.steps.mapIndexed { index, action -> "${index + 1}. ${action.kind}" },
            millis = clock.nowMillis() - started,
        )
    }

    /**
     * A hand-written graph for a known app.
     *
     * It executes at most a few steps, each through the normal executor, so an
     * approval or a failed tap stops it honestly. A miss on the first screen
     * returns null and the model handles the turn; a miss after some progress
     * returns a partial outcome that names what was opened.
     */
    private suspend fun graph(
        request: TurnRequest,
        started: Long,
        tables: CatalogSnapshot,
        isCancelled: () -> Boolean,
    ): TurnOutcome? {
        val source = graphs ?: return null
        var observation = runCatching { request.device.observe() }.getOrNull() ?: return null
        val executor = executorFor(request.device)
        val records = mutableListOf<RunRecord>()
        val narration = mutableListOf<String>()
        val seen = mutableSetOf<String>()
        var answer: String = ""
        for (step in 0 until MAX_GRAPH_STEPS) {
            if (isCancelled()) {
                break
            }
            val next = runCatching { source.next(observation, request.goal) }.getOrNull()
                ?: break
            val signature = ActionSignature.of(next.action)
            // Back is how a graph walks out of a screen it did not expect; a
            // second identical tap or scroll is a loop, a second back is not.
            if (next.action.kind != "ui.back" && !seen.add(signature)) {
                break
            }
            val result = runCatching {
                executor.execute(
                    runId = request.runId,
                    step = step,
                    traceId = request.traceId,
                    action = next.action,
                    before = observation,
                )
            }.getOrNull() ?: break
            records += result.record
            narration += RunNarrator.lines(listOf(result.record))
            observation = result.observation
            if (!result.record.executed || !result.record.error.isNullOrBlank()) {
                return TurnOutcome(
                    source = TurnSource.GRAPH,
                    knowledgeVersion = tables.version,
                    answer = "I could not finish that in ${next.graph}.",
                    records = records,
                    narration = narration,
                    error = HopaError(
                        ErrorCodes.BLOCKED,
                        result.record.error ?: "the graph step did not run",
                    ),
                    surfaceName = request.surfaceName,
                    finalScreen = observation,
                    millis = clock.nowMillis() - started,
                )
            }
            if (next.answer.isNotBlank()) {
                answer = next.answer
            }
            if (next.done) {
                return TurnOutcome(
                    source = TurnSource.GRAPH,
                    knowledgeVersion = tables.version,
                    answer = answer.ifBlank { "Done." },
                    records = records,
                    narration = narration,
                    surfaceName = request.surfaceName,
                    finalScreen = observation,
                    millis = clock.nowMillis() - started,
                )
            }
            // The executor reads the screen the instant the tap lands, often
            // before the next page has drawn. Read again after the settle, or the
            // graph judges a transition and finds nothing to do.
            settle(GRAPH_SETTLE_MS)
            observation = runCatching { request.device.observe() }.getOrNull() ?: observation
        }
        if (records.isEmpty()) {
            return null
        }
        return TurnOutcome(
            source = TurnSource.GRAPH,
            knowledgeVersion = tables.version,
            answer = answer.ifBlank {
                "I opened the app, but I do not know the next step for that goal."
            },
            records = records,
            narration = narration,
            surfaceName = request.surfaceName,
            finalScreen = observation,
            millis = clock.nowMillis() - started,
        )
    }

    private suspend fun fromModel(
        request: TurnRequest,
        started: Long,
        isCancelled: () -> Boolean,
        tables: CatalogSnapshot,
    ): TurnOutcome {
        val loop = AgentLoop(
            stepPolicy = steps,
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
            )
        }

        if (result == null) {
            return TurnOutcome(
                source = TurnSource.MODEL,
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

        return TurnOutcome(
            source = TurnSource.MODEL,
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
        /** A hand-written graph is five edges at most; beyond that it is a plan. */
        const val MAX_GRAPH_STEPS = 5
        const val GRAPH_SETTLE_MS = 800L
    }
}
