package com.hopa.engine.loop

import com.hopa.engine.contracts.ErrorCodes
import com.hopa.engine.contracts.HopaError
import com.hopa.engine.contracts.Observation
import com.hopa.engine.contracts.ObservationNode
import com.hopa.engine.contracts.RunRecord
import com.hopa.engine.contracts.ScreenSize
import com.hopa.engine.gate.ActionExecutor
import com.hopa.engine.model.ModelMessage
import com.hopa.engine.model.ModelPort
import com.hopa.engine.model.ModelRequest
import com.hopa.engine.model.ModelUsage
import com.hopa.engine.parser.DecisionParser
import com.hopa.engine.ports.Clock
import com.hopa.engine.ports.DevicePort
import com.hopa.engine.prompt.AppCatalogBlock
import com.hopa.engine.prompt.ContextBudget
import com.hopa.engine.prompt.InstalledAppsBlock
import com.hopa.engine.prompt.ScreenRenderer
import com.hopa.engine.prompt.SystemPromptBuilder
import com.hopa.engine.records.RunRecorder
import com.hopa.engine.router.AppRouter
import com.hopa.engine.router.CatalogRoutes
import com.hopa.engine.router.RouterHint

class AgentLoop(
    private val model: ModelPort,
    private val device: DevicePort,
    private val executor: ActionExecutor,
    private val recorder: RunRecorder,
    private val clock: Clock,
    private val parser: DecisionParser = DecisionParser(),
    private val promptBuilder: SystemPromptBuilder = SystemPromptBuilder(),
    private val budget: ContextBudget = ContextBudget(),
    private val screenRenderer: ScreenRenderer = ScreenRenderer(),
    private val config: LoopConfig = LoopConfig(),
    private val webAvailable: Boolean = false,
) {
    suspend fun run(
        runId: String,
        traceId: String,
        context: TurnContext,
        isCancelled: () -> Boolean = { false },
    ): TurnResult {
        var observation = runCatching { device.observe() }.getOrNull()
        val surfaceAvailable = observation != null
        val targets = CatalogRoutes.targets(context.installedApps, context.platform)
        val route = AppRouter.route(context.goal, targets)
        val known = targets
            .filter { it.bundle.isNotBlank() }
            .map { it.bundle.lowercase() }
            .toSet()
        val names = targets
            .filter { it.bundle.isNotBlank() }
            .associate { it.bundle.lowercase() to it.display }
        val installed = if (
            context.platform.equals("android", ignoreCase = true) ||
            context.installedApps.isNotEmpty()
        ) {
            InstalledAppsBlock().text(context.installedApps, known)
        } else {
            ""
        }
        val system = promptBuilder.build(
            memory = context.memory,
            skills = context.skills,
            apps = listOf(
                AppCatalogBlock.text(targets),
                installed,
                typedFunctions(context.appFunctions),
            ).filter { it.isNotEmpty() }.joinToString("\n\n"),
            routerHint = RouterHint.text(route, webAvailable),
            surfaceAvailable = surfaceAvailable,
            webAvailable = webAvailable,
            phoneAccess = context.phoneAccess,
            vision = context.vision,
        )
        val messages = mutableListOf(ModelMessage("system", system))
        messages += budget.fit(context.history)
        messages += ModelMessage("user", context.goal)
        if (observation != null) {
            messages += ModelMessage("user", screenRenderer.render(observation))
        }

        val records = mutableListOf<RunRecord>()
        val narration = mutableListOf<String>()
        val steps = mutableListOf<String>()
        val launched = mutableSetOf<String>()
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
            val reply = runCatching { model.complete(ModelRequest(messages, images = frames)) }
                .getOrElse { error ->
                    return TurnResult(
                        answer = "I could not reach the model. Check the provider and network.",
                        records = records,
                        narration = narration,
                        error = HopaError(ErrorCodes.MODEL, error.message ?: "model failed"),
                        usage = usage,
                    )
                }
            usage = usage.plus(reply.usage)
            messages += ModelMessage("assistant", reply.text)

            val outcome = parser.parse(reply.text)
            outcome.error?.let { failure ->
                return TurnResult(
                    answer = "The model sent an invalid step. ${failure.message}",
                    records = records,
                    narration = narration,
                    error = failure,
                    usage = usage,
                )
            }
            outcome.text?.let { text ->
                return TurnResult(ModelReplyText.clean(text), records, narration, usage = usage)
            }
            val decision = outcome.decision
                ?: return TurnResult("I did not understand the answer.", records, narration, usage = usage)
            if (decision.done) {
                return TurnResult(
                    answer = ModelReplyText.clean(decision.say.ifBlank { "Done." }),
                    records = records,
                    narration = narration,
                    usage = usage,
                )
            }
            if (decision.needUser) {
                return TurnResult(
                    answer = ModelReplyText.clean(decision.say),
                    records = records,
                    narration = narration,
                    options = decision.options.orEmpty(),
                    usage = usage,
                )
            }
            val action = decision.action
                ?: return TurnResult(
                    ModelReplyText.clean(decision.say.ifBlank { "Done." }),
                    records,
                    narration,
                    usage = usage,
                )

            if (action.kind == "ui.launch") {
                val app = action.app.orEmpty()
                if (app.isNotEmpty() && !launched.add(app)) {
                    messages += ModelMessage(
                        "user",
                        "The app $app is already in the foreground. Do not launch it again; " +
                            "read SCREEN TREE and continue.",
                    )
                    return@repeat
                }
            }

            val signature = "${action.kind}|${action.ref}|${action.text}|${action.app}|${action.x},${action.y}"
            if (action.kind !in READ_ONLY_KINDS) {
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
            messages += ModelMessage("user", screenRenderer.render(result.observation))
            if (result.text.isNotEmpty()) {
                messages += ModelMessage("user", result.text)
            }
        }

        if (isCancelled()) {
            return TurnResult("Stopped.", records, narration, usage = usage)
        }
        messages += ModelMessage(
            "user",
            "You have reached the step limit. Summarize what happened and answer in plain text.",
        )
        val final = runCatching { model.complete(ModelRequest(messages)) }
        final.getOrNull()?.let { usage = usage.plus(it.usage) }
        return TurnResult(
            answer = final.map { it.text }.getOrElse { "I stopped after ${config.maxSteps} steps." },
            records = records,
            narration = narration,
            error = if (final.isSuccess) null else HopaError(ErrorCodes.TIMEOUT, "step limit"),
            usage = usage,
        )
    }

    private companion object {
        /** Reading the screen again is not a loop; acting on it twice is. */
        val READ_ONLY_KINDS = setOf("ui.observe", "ui.wait", "web.read")
    }

    /** A short block for the foreground app's typed functions, when it has any. */
    private fun typedFunctions(raw: String): String {
        val text = raw.trim()
        if (text.isEmpty() || text.startsWith("err")) {
            return ""
        }
        return "TYPED FUNCTIONS OF THE CURRENT APP (call these instead of tapping):\n" +
            text.take(1_500)
    }

    private fun emptyObservation(): Observation = Observation(
        id = "obs-empty",
        timestamp = clock.nowMillis(),
        screenSize = ScreenSize(width = 0, height = 0),
        tree = ObservationNode(type = "root"),
    )
}
