package com.hopa.core.loop

import com.hopa.core.contracts.ErrorCodes
import com.hopa.core.contracts.HopaError
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.RunRecord
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.gate.ActionExecutor
import com.hopa.core.model.ModelMessage
import com.hopa.core.model.ModelPort
import com.hopa.core.model.ModelRequest
import com.hopa.core.narration.RunNarrator
import com.hopa.core.parser.DecisionParser
import com.hopa.core.ports.Clock
import com.hopa.core.ports.DevicePort
import com.hopa.core.prompt.AppCatalogBlock
import com.hopa.core.prompt.ContextBudget
import com.hopa.core.prompt.ScreenRenderer
import com.hopa.core.prompt.SystemPromptBuilder
import com.hopa.core.records.RunRecorder
import com.hopa.core.router.AppRouter
import com.hopa.core.router.CatalogRoutes
import com.hopa.core.router.RouterHint

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
    ): TurnResult {
        var observation = runCatching { device.observe() }.getOrNull()
        val surfaceAvailable = observation != null
        val route = AppRouter.route(context.goal, CatalogRoutes.targets())
        val system = promptBuilder.build(
            memory = context.memory,
            skills = context.skills,
            apps = AppCatalogBlock.text(),
            routerHint = RouterHint.text(route),
            surfaceAvailable = surfaceAvailable,
            webAvailable = webAvailable,
        )
        val messages = mutableListOf(ModelMessage("system", system))
        messages += budget.fit(context.history)
        messages += ModelMessage("user", context.goal)
        if (observation != null) {
            messages += ModelMessage("user", screenRenderer.render(observation))
        }

        val records = mutableListOf<RunRecord>()
        val narration = mutableListOf<String>()

        repeat(config.maxSteps) { step ->
            val reply = runCatching { model.complete(ModelRequest(messages)) }
                .getOrElse { error ->
                    return TurnResult(
                        answer = "I could not reach the model. Check the provider and network.",
                        records = records,
                        narration = narration,
                        error = HopaError(ErrorCodes.MODEL, error.message ?: "model failed"),
                    )
                }
            messages += ModelMessage("assistant", reply.text)
            when (val outcome = parser.parse(reply.text)) {
                else -> {
                    val failure = outcome.error
                    if (failure != null) {
                        return TurnResult(
                            answer = "The model sent an invalid step. ${failure.message}",
                            records = records,
                            narration = narration,
                            error = failure,
                        )
                    }
                    val text = outcome.text
                    if (text != null) {
                        return TurnResult(text, records, narration)
                    }
                    val decision = outcome.decision
                    if (decision == null) {
                        return TurnResult("I did not understand the answer.", records, narration)
                    }
                    if (decision.done) {
                        return TurnResult(decision.say.ifBlank { "Done." }, records, narration)
                    }
                    if (decision.needUser) {
                        return TurnResult(
                            answer = decision.say,
                            records = records,
                            narration = narration,
                            options = decision.options.orEmpty(),
                        )
                    }
                    val action = decision.action
                    if (action == null) {
                        return TurnResult(decision.say.ifBlank { "Done." }, records, narration)
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
                    narration += RunNarrator.line(action, result.record.executed)
                    observation = result.observation
                    messages += ModelMessage("user", screenRenderer.render(result.observation))
                    if (result.text.isNotEmpty()) {
                        messages += ModelMessage("user", result.text)
                    }
                }
            }
        }

        messages += ModelMessage(
            "user",
            "You have reached the step limit. Summarize what happened and answer in plain text.",
        )
        val final = runCatching { model.complete(ModelRequest(messages)) }
        return TurnResult(
            answer = final.map { it.text }.getOrElse { "I stopped after ${config.maxSteps} steps." },
            records = records,
            narration = narration,
            error = if (final.isSuccess) null else HopaError(ErrorCodes.TIMEOUT, "step limit"),
        )
    }

    private fun emptyObservation(): Observation = Observation(
        id = "obs-empty",
        timestamp = clock.nowMillis(),
        screenSize = ScreenSize(width = 0, height = 0),
        tree = ObservationNode(type = "root"),
    )
}
