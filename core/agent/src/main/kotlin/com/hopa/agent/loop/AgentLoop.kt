package com.hopa.agent.loop

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.classify.ActionKindRules
import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.agent.decision.DecisionRuntime
import com.hopa.agent.prompt.ScreenRenderer
import com.hopa.catalog.routing.CatalogRoutes
import com.hopa.catalog.store.CatalogSnapshot
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.error.HopaError
import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.ports.Clock
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.turn.TurnResult
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.RunRecord
import com.hopa.contracts.wire.ScreenSize
import com.hopa.decision.ActionCandidate
import com.hopa.decision.ActionClass
import com.hopa.decision.Verb
import com.hopa.runlog.store.RunRecorder

/**
 * The step loop. One question per pass: what is the next move?
 *
 * The answer comes from a [DecisionPolicy], not from a model: a graph, a rule
 * layer and a language model all answer with the same [Decision], so the loop
 * never learns which one spoke. A policy that knows no safe next step says
 * [Decision.NoPath] and its caller tries the next one.
 */
class AgentLoop(
    /** Where the next move comes from; a single policy or a chain of them. */
    private val policy: DecisionPolicy,
    private val device: DevicePort,
    private val executor: ActionExecutor,
    private val recorder: RunRecorder,
    private val clock: Clock,
    private val screenRenderer: ScreenRenderer = ScreenRenderer(),
    private val config: LoopConfig = LoopConfig(),
    private val webAvailable: Boolean = false,
    /** The tables this turn routes and names apps with. */
    private val knowledge: CatalogSnapshot,
    /**
     * The decision layers. In shadow mode they vote into the run log and the
     * policy still decides; nothing here changes what executes.
     */
    private val decisions: DecisionRuntime? = null,
) {
    suspend fun run(
        runId: String,
        traceId: String,
        context: TurnContext,
        isCancelled: () -> Boolean = { false },
    ): TurnResult {
        var observation = runCatching { device.observe() }.getOrNull()
        val targets = CatalogRoutes.targets(context.installedApps, context.platform, knowledge)
        val names = targets
            .filter { it.bundle.isNotBlank() }
            .associate { it.bundle.lowercase() to it.display }

        val records = mutableListOf<RunRecord>()
        val narration = mutableListOf<String>()
        val steps = mutableListOf<String>()
        val launched = mutableSetOf<String>()

        // What earlier steps did; the policy turns this into messages.
        val notes = mutableListOf<ModelMessage>()
        var usage = ModelUsage()

        repeat(config.maxSteps) { step ->
            if (isCancelled()) {
                return TurnResult("Stopped.", records, narration, usage = usage)
            }
            val frames = if (context.vision) {
                runCatching { device.screenshot() }.getOrNull()?.let { bytes ->
                    listOf(java.util.Base64.getEncoder().encodeToString(bytes))
                }.orEmpty()
            } else {
                emptyList()
            }

            val outcome = policy.decide(
                DecisionInput(
                    context = context,
                    observation = observation,
                    step = step,
                    notes = notes.toList(),
                    webAvailable = webAvailable,
                    screenshot = frames.firstOrNull(),
                ),
            )
            usage = usage.plus(outcome.usage)
            outcome.raw?.let { notes += ModelMessage("assistant", it) }

            when (val decision = outcome.decision) {
                is Decision.Failed -> return TurnResult(
                    answer = "I could not decide the next step: ${decision.error.message}. " +
                        "Check the provider and the screen.",
                    records = records,
                    narration = narration,
                    error = decision.error,
                    usage = usage,
                )

                Decision.NoPath -> return TurnResult(
                    answer = "I could not find a safe next step on this screen, so I stopped.",
                    records = records,
                    narration = narration,
                    error = HopaError(ErrorCodes.BLOCKED, "no path for this screen"),
                    usage = usage,
                )

                is Decision.Say -> return TurnResult(
                    answer = decision.answer,
                    records = records,
                    narration = narration,
                    error = decision.error,
                    usage = usage,
                )

                is Decision.Ask -> return TurnResult(
                    answer = decision.answer,
                    records = records,
                    narration = narration,
                    options = decision.options,
                    usage = usage,
                )

                is Decision.Act -> Unit
            }

            val action = outcome.decision.action
            val then = outcome.decision.then

            // Every active layer votes here. The selected one applies only for
            // the classes the runtime allows, and only to change the step, never
            // the approval: a payment still goes through the gate.
            val run = decisions?.observe(
                runId = runId,
                step = step,
                action = action,
                screen = observation?.let(screenRenderer::render).orEmpty(),
                history = steps.toList(),
                goal = context.goal,
                candidates = listOf(ActionCandidate("proposed", action)),
            )
            val chosen = run?.decision
            if (chosen != null && decisions.appliesTo(ActionClass.of(action.kindOrNull()))) {
                when (chosen.verb) {
                    Verb.ACT -> Unit

                    Verb.VERIFY -> {
                        observation = runCatching { device.observe() }.getOrNull() ?: observation
                        observation?.let {
                            notes += ModelMessage("user", "LOOK AGAIN\n" + screenRenderer.render(it))
                        }
                        return@repeat
                    }

                    Verb.WAIT -> return TurnResult(
                        answer = "I am waiting: ${chosen.trace}",
                        records = records,
                        narration = narration,
                        usage = usage,
                    )

                    Verb.ASK -> return TurnResult(
                        answer = "I need your go-ahead before this step. ${chosen.trace}",
                        records = records,
                        narration = narration,
                        usage = usage,
                    )

                    Verb.ESCALATE -> return TurnResult(
                        answer = "I need you to take over: ${chosen.trace}",
                        records = records,
                        narration = narration,
                        error = HopaError(ErrorCodes.BLOCKED, chosen.reason),
                        usage = usage,
                    )
                }
            }

            if (action.kind == "ui.launch") {
                val app = action.app.orEmpty()
                if (app.isNotEmpty() && !launched.add(app)) {
                    notes += ModelMessage(
                        "user",
                        "The app $app is already in the foreground. Do not launch it again; " +
                            "read SCREEN TREE and continue.",
                    )
                    return@repeat
                }
            }

            val signature = "${action.kind}|${action.ref}|${action.text}|${action.app}|${action.x},${action.y}"
            if (action.kindOrNull() !in ActionKindRules.READ_ONLY) {
                steps += signature
            }
            if (steps.count { it == signature } >= 3) {
                // Tapping the same field forever is a failure, not progress.
                return TurnResult(
                    answer = "I kept repeating the same step, so I stopped. " +
                        "The screen did not react the way I expected.",
                    records = records,
                    narration = narration,
                    error = HopaError(ErrorCodes.BLOCKED, "repeated action: ${action.kind}"),
                    usage = usage,
                )
            }
            if (isCancelled()) {
                return TurnResult("Stopped.", records, narration, usage = usage)
            }
            val before = observation ?: emptyObservation()
            val result = executor.execute(
                runId = runId,
                step = step,
                traceId = traceId,
                action = action,
                before = before,
            )
            records += result.record
            narration += RunNarrator.line(action, result.record.executed, result.record.error, names)
            observation = result.observation
            clock.sleep(config.settleMillis)
            notes += ModelMessage("user", screenRenderer.render(result.observation))
            if (result.text.isNotEmpty()) {
                notes += ModelMessage("user", result.text)
            }
            // The policy said this action finishes the goal: answer and stop.
            if (then != null) {
                return TurnResult(then, records, narration, usage = usage)
            }
        }

        if (isCancelled()) {
            return TurnResult("Stopped.", records, narration, usage = usage)
        }
        val final = policy.decide(
            DecisionInput(
                context = context,
                observation = observation,
                step = config.maxSteps,
                notes = notes.toList(),
                webAvailable = webAvailable,
                atStepLimit = true,
            ),
        )
        usage = usage.plus(final.usage)
        return when (val decision = final.decision) {
            is Decision.Say -> TurnResult(decision.answer, records, narration, usage = usage)

            is Decision.Ask -> TurnResult(
                answer = decision.answer,
                records = records,
                narration = narration,
                options = decision.options,
                usage = usage,
            )

            else -> TurnResult(
                answer = "I stopped after ${config.maxSteps} steps.",
                records = records,
                narration = narration,
                error = HopaError(ErrorCodes.TIMEOUT, "step limit"),
                usage = usage,
            )
        }
    }

    private fun emptyObservation(): Observation = Observation(
        id = "obs-empty",
        timestamp = clock.nowMillis(),
        screenSize = ScreenSize(width = 0, height = 0),
        tree = ObservationNode(type = "root"),
    )
}
