package com.hopa.agent.decision.model

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.agent.decision.StepPolicy
import com.hopa.agent.prompt.AppCatalogBlock
import com.hopa.agent.prompt.ContextBudget
import com.hopa.agent.prompt.InstalledAppsBlock
import com.hopa.agent.prompt.ScreenRenderer
import com.hopa.agent.prompt.SystemPromptBuilder
import com.hopa.catalog.routing.AppRouter
import com.hopa.catalog.routing.CatalogRoutes
import com.hopa.catalog.routing.RouterHint
import com.hopa.catalog.store.CatalogSnapshot
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.error.HopaError
import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.model.ModelRequest

/**
 * The language-model policy: it builds the prompt from the observation, asks the
 * provider and turns the reply into a [Decision]. Everything model-shaped lives
 * here, so a graph or a rule layer never has to pretend to be a model.
 */
class ModelDecisionPolicy(
    private val steps: StepPolicy,
    /** The tables this client uses; read per call, so an update applies next turn. */
    private val knowledge: () -> CatalogSnapshot,
    private val promptBuilder: SystemPromptBuilder = SystemPromptBuilder(),
    private val budget: ContextBudget = ContextBudget(),
    private val screenRenderer: ScreenRenderer = ScreenRenderer(),
    private val parser: DecisionParser = DecisionParser(),
) : DecisionPolicy {
    override val name: String = "model"

    override suspend fun decide(input: DecisionInput): DecisionOutcome {
        val context = input.context
        val observation = input.observation
        val tables = knowledge()
        val targets = CatalogRoutes.targets(context.installedApps, context.platform, tables)
        val route = AppRouter.route(context.goal, targets)
        val known = targets.filter { it.bundle.isNotBlank() }.map { it.bundle.lowercase() }.toSet()
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
            routerHint = RouterHint.text(route, input.webAvailable),
            surfaceAvailable = observation != null,
            webAvailable = input.webAvailable,
            phoneAccess = context.phoneAccess,
            vision = context.vision,
        )
        val messages = buildList {
            add(ModelMessage("system", system))
            addAll(budget.fit(context.history))
            add(ModelMessage("user", context.goal))
            observation?.let { add(ModelMessage("user", screenRenderer.render(it))) }
            addAll(input.notes)
            if (input.atStepLimit) {
                add(ModelMessage("user", STEP_LIMIT))
            }
        }

        val reply = runCatching { steps.next(ModelRequest(messages, images = listOfNotNull(input.screenshot))) }
            .getOrElse { error ->
                return DecisionOutcome(
                    Decision.Failed(HopaError(ErrorCodes.MODEL, error.message ?: "model failed")),
                )
            }
        val usage = reply.usage

        if (input.atStepLimit) {
            return DecisionOutcome(Decision.Say(ModelReplyText.clean(reply.text)), usage, raw = reply.text)
        }

        val outcome = parser.parse(reply.text)
        outcome.error?.let { return DecisionOutcome(Decision.Failed(it), usage, raw = reply.text) }
        outcome.text?.let { return DecisionOutcome(Decision.Say(ModelReplyText.clean(it)), usage, raw = reply.text) }

        val decision = outcome.decision
            ?: return DecisionOutcome(Decision.Say("I did not understand the answer."), usage, raw = reply.text)
        if (decision.done) {
            return DecisionOutcome(
                Decision.Say(ModelReplyText.clean(decision.say.ifBlank { "Done." })),
                usage,
                raw = reply.text,
            )
        }
        if (decision.needUser) {
            return DecisionOutcome(
                Decision.Ask(ModelReplyText.clean(decision.say), decision.options.orEmpty()),
                usage,
            )
        }
        val action = decision.action
            ?: return DecisionOutcome(
                Decision.Say(ModelReplyText.clean(decision.say.ifBlank { "Done." })),
                usage,
                raw = reply.text,
            )
        return DecisionOutcome(Decision.Act(action), usage, raw = reply.text)
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

    private companion object {
        const val STEP_LIMIT =
            "You have reached the step limit. Summarize what happened and answer in plain text."
    }
}
