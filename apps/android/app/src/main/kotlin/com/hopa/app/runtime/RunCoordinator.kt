package com.hopa.app.runtime

import com.hopa.app.di.AppContainer
import com.hopa.capabilities.device.UnavailableDevicePort
import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.ports.DevicePort
import com.hopa.agent.decision.model.ModelStepPolicy
import com.hopa.observation.source.ScreenSourceDevice
import com.hopa.stores.AppSettings
import com.hopa.agent.goal.Checkpoint
import com.hopa.agent.plan.ModelPlanSource
import com.hopa.agent.recipe.ReplayAnswer
import com.hopa.agent.turn.TurnOutcome
import com.hopa.agent.turn.TurnRequest
import com.hopa.agent.turn.TurnRunner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext

/**
 * The app's one way into a turn: it knows where the ports are, what the person
 * set, and how to describe this phone. [TurnRunner] knows what a turn is, so the
 * chat screen, a parallel run and a delivered task stop carrying their own copy
 * of plan-first, replay and recipe saving.
 */
class RunCoordinator(
    private val container: AppContainer,
) {
    private val runner by lazy {
        TurnRunner(
            steps = ModelStepPolicy(container.model),
            fallbackSteps = ModelStepPolicy(container.cloudModel),
            executorFor = container::executorFor,
            recorder = container.recorder,
            clock = container.clock,
            recipes = container.recipes,
            replayAnswer = ReplayAnswer(container.model),
            plans = ModelPlanSource(container.model) { planEnvironment() },
            knowledge = { container.knowledge },
            decisions = container.decisions,
            commands = container.commands,
            graphs = container.graphs,
        )
    }

    /**
     * What the planner has to know to write steps a phone can follow. The turn
     * prompt gets the same facts; the plan prompt used to get none, so it told
     * the person to identify the device and offered Windows and macOS.
     */
    private suspend fun planEnvironment(): String {
        val current = container.settings.settings.first()
        val apps = withContext(Dispatchers.IO) {
            runCatching { container.packages.installed() }.getOrDefault(emptyList())
        }
            .map { it.label.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
            .sorted()
            .take(MAX_PLAN_APPS)
        val hidden = current.screenPath == "auto" || current.screenPath == "background"
        return buildString {
            append("This is an Android phone. HOPA acts on it; you write the steps it takes.")
            append("\n")
            append(
                if (hidden) {
                    "The apps open on a hidden screen on this phone, so the person's own screen stays free."
                } else {
                    "The apps open on this phone's screen, with the person watching each tap."
                },
            )
            if (apps.isNotEmpty()) {
                append("\n")
                append("Apps on this phone: ")
                append(apps.joinToString(", "))
                append(".")
            }
            append("\nSteps are actions on this phone: open an app, tap a control by its text, ")
            append("type, scroll, wait, then check the result.")
            append("\nDo not say you cannot see the screen, and do not mention a computer, ")
            append("Windows, macOS or any other device.")
        }
    }

    private companion object {
        /** Enough to name the usual apps without turning the prompt into a list. */
        const val MAX_PLAN_APPS = 40
    }

    /** Everything this client can tell the runner about the screen and the person. */
    suspend fun request(
        goal: String,
        device: ScreenSourceDevice,
        settings: AppSettings,
        runId: String,
        traceId: String,
        history: List<ModelMessage> = emptyList(),
        checkpoints: List<Checkpoint> = emptyList(),
        extraMemory: String = "",
        appFunctions: String? = null,
        phoneAccess: Boolean? = null,
    ): TurnRequest {
        val facts = runCatching { container.memory.promptText() }.getOrDefault("")
        val character = "Character: ${settings.tone} tone, ${settings.chattiness} length."
        val memory = listOf(extraMemory, facts, character)
            .filter { it.isNotBlank() }
            .joinToString("\n\n")
        return TurnRequest(
            goal = goal,
            device = device,
            runId = runId,
            traceId = traceId,
            history = history,
            memory = memory,
            skills = runCatching { container.skills.promptText() }.getOrDefault(""),
            installedApps = runCatching { container.packages.installed() }.getOrDefault(emptyList()),
            platform = "android",
            vision = settings.vision,
            appFunctions = appFunctions ?: typedFunctions(device),
            phoneAccess = phoneAccess ?: (device.sourceName != "fallback"),
            checkpoints = checkpoints,
            replay = settings.replaySkills,
            instantCommands = settings.instantCommands,
            useGraphs = settings.stepSource != "model",
            graphFallback = settings.stepSource != "graph",
            cloudFallback = settings.cloudFallback,
            surfaceName = device.sourceName,
            surfaceAvailable = device.sourceName != "fallback",
            surfaceError = device.lastError,
        )
    }

    /**
     * The plan gate asks for steps, so it gets no surface and no phone facts: a
     * plan must never open the hidden display or query the helper.
     */
    fun planRequest(goal: String, runId: String, traceId: String): TurnRequest = TurnRequest(
        goal = goal,
        device = ScreenSourceDevice(emptyList(), UnavailableDevicePort()),
        runId = runId,
        traceId = traceId,
        planFirst = true,
    )

    suspend fun run(
        request: TurnRequest,
        isCancelled: () -> Boolean = { false },
    ): TurnOutcome = runner.run(request, isCancelled)

    /**
     * Ask the helper what the foreground app publishes, so the model can choose a
     * typed call over a series of taps. Empty when no shell is available.
     */
    private suspend fun typedFunctions(device: DevicePort): String = withContext(Dispatchers.IO) {
        // The helper is reached over a local socket: never from the main thread.
        if (!container.shell.connected) {
            return@withContext ""
        }
        val foreground = runCatching { device.foreground() }.getOrDefault("")
        if (foreground.isBlank()) {
            return@withContext ""
        }
        runCatching { container.shell.appFunctions(foreground).second }.getOrDefault("")
    }
}
