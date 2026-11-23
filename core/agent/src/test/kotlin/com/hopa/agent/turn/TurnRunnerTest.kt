package com.hopa.agent.turn

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.action.ApprovalPolicy
import com.hopa.agent.decision.DecisionRuntime
import com.hopa.agent.decision.StepPolicy
import com.hopa.agent.goal.Checkpoint
import com.hopa.agent.plan.PlanSource
import com.hopa.agent.recipe.RecipeStore
import com.hopa.catalog.data.ApprovalPolicyData
import com.hopa.catalog.store.CatalogSnapshot
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest
import com.hopa.contracts.model.ModelUsage
import com.hopa.contracts.ports.Clock
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.ports.InstalledApp
import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.ScreenSize
import com.hopa.decision.ActionClass
import com.hopa.decision.ConformanceStatus
import com.hopa.decision.DecisionContext
import com.hopa.decision.DecisionCoordinator
import com.hopa.decision.DecisionLayer
import com.hopa.decision.DecisionMode
import com.hopa.decision.DecisionRegistry
import com.hopa.decision.DecisionRun
import com.hopa.decision.LatencyClass
import com.hopa.decision.LayerDecision
import com.hopa.decision.LayerMetadata
import com.hopa.decision.LayerStatus
import com.hopa.decision.Verb
import com.hopa.decision.classifier.IntentClassifier
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.runlog.store.InMemoryRunRecorder
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

private const val SETTINGS = "com.android.settings"

class TurnRunnerTest {
    @TempDir
    lateinit var folder: File

    // ── Fakes ─────────────────────────────────────────────────────────────────

    private class FakeClock : Clock {
        override fun nowMillis(): Long = 1_000L

        override suspend fun sleep(millis: Long) = Unit
    }

    private class FakeGraph(
        private val steps: List<com.hopa.decision.graph.GraphStep>,
        private val planned: com.hopa.decision.graph.GraphTarget? = null,
    ) : com.hopa.decision.graph.GraphStepSource {
        private var index = 0

        override fun next(observation: Observation, goal: String): com.hopa.decision.graph.GraphStep? {
            return steps.getOrNull(index++)
        }

        override fun target(goal: String): com.hopa.decision.graph.GraphTarget? = planned
    }

    private class ScriptedPolicy(private val replies: List<String>) : StepPolicy {
        var calls: Int = 0
            private set

        override suspend fun next(request: ModelRequest): ModelReply {
            check(replies.isNotEmpty()) { "the model must not be called in this test" }
            val text = replies[minOf(calls, replies.lastIndex)]
            calls += 1
            return ModelReply(text, ModelUsage(totalTokens = 5))
        }
    }

    private object AlwaysApprove : ApprovalGateway {
        override suspend fun approve(request: ApprovalRequest): Boolean = true
    }

    private class FakeDevice(screens: List<Observation>) : DevicePort {
        private val screens = screens
        private var index = 0

        var observed: Int = 0
            private set
        val taps = mutableListOf<String>()
        val launches = mutableListOf<String>()

        override suspend fun observe(): Observation {
            observed += 1
            return screens[index.coerceAtMost(screens.lastIndex)]
        }

        override suspend fun tap(ref: String?, x: Int?, y: Int?) {
            taps += ref ?: "$x,$y"
            advance()
        }

        override suspend fun type(text: String, ref: String?) = advance()

        override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) = advance()

        override suspend fun pressBack() = advance()

        override suspend fun pressHome() = advance()

        override suspend fun launch(packageName: String) {
            launches += packageName
        }

        override suspend fun stop(packageName: String) = Unit

        override suspend fun foreground(): String = SETTINGS

        override suspend fun screenshot(): ByteArray? = null

        override suspend fun apps(): List<InstalledApp> = emptyList()

        private fun advance() {
            if (index < screens.lastIndex) {
                index += 1
            }
        }
    }

    private class Harness(
        screens: List<Observation>,
        replies: List<String> = emptyList(),
        plan: List<String>? = null,
        store: RecipeStore? = null,
        commands: Boolean = false,
        decisions: com.hopa.agent.decision.DecisionRuntime? = null,
        graphs: com.hopa.decision.graph.GraphStepSource? = null,
    ) {
        val device = FakeDevice(screens)
        val policy = ScriptedPolicy(replies)
        private val knowledge = CatalogSnapshot(
            version = "test",
            catalog = emptyList(),
            sites = emptyList(),
            approval = ApprovalPolicyData,
            promptRules = emptyList(),
        )
        private val clock = FakeClock()
        private val recorder = InMemoryRunRecorder()
        private val executor = ActionExecutor(
            device = device,
            browser = null,
            system = null,
            sandbox = null,
            policy = { ApprovalPolicy() },
            approval = AlwaysApprove,
            recorder = recorder,
            factory = RunRecordFactory(clock),
            clock = clock,
        )
        val runner = TurnRunner(
            steps = policy,
            executorFor = { executor },
            recorder = recorder,
            clock = clock,
            recipes = store,
            plans = plan?.let { planned -> PlanSource { planned } },
            knowledge = { knowledge },
            settle = {},
            commands = if (commands) IntentClassifier() else null,
            decisions = decisions,
            graphs = graphs,
        )

        fun request(
            goal: String,
            planFirst: Boolean = false,
            planApproved: Boolean = false,
            checkpoints: List<Checkpoint> = emptyList(),
            surfaceAvailable: Boolean = true,
            surfaceError: String = "",
        ): TurnRequest = TurnRequest(
            goal = goal,
            device = device,
            runId = "run-1",
            traceId = "trace-1",
            installedApps = listOf(InstalledApp(SETTINGS, "Settings")),
            platform = "android",
            surfaceName = "accessibility",
            checkpoints = checkpoints,
            planFirst = planFirst,
            planApproved = planApproved,
            surfaceAvailable = surfaceAvailable,
            surfaceError = surfaceError,
        )
    }

    private fun labelled(text: String): Observation = observation(
        ObservationNode(
            ref = "e1",
            type = "TextView",
            text = text,
            id = "android:id/title",
        ),
    )

    private fun observation(vararg nodes: ObservationNode): Observation = Observation(
        id = "obs-${nodes.joinToString { it.text }}",
        timestamp = 1L,
        screenSize = ScreenSize(width = 1080, height = 2400),
        tree = ObservationNode(type = "root", children = nodes.toList()),
    )

    private fun store(): RecipeStore = RecipeStore(File(folder, "recipes.txt"))

    // ── Tests ─────────────────────────────────────────────────────────────────

    @Test
    fun a_plan_comes_back_before_anything_is_tapped() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            plan = listOf("Open Settings", "Tap Connections"),
        )

        val outcome = harness.runner.run(harness.request("Open connections", planFirst = true))

        assertEquals(TurnSource.PLAN, outcome.source)
        assertEquals(listOf("Open Settings", "Tap Connections"), outcome.pendingPlan)
        assertEquals(0, harness.device.observed)
        assertNull(outcome.error)
    }

    @Test
    fun a_plan_gate_with_no_source_says_so_instead_of_running() = runBlocking {
        val harness = Harness(screens = listOf(labelled("Settings")))

        val outcome = harness.runner.run(harness.request("Open connections", planFirst = true))

        assertEquals(TurnSource.PLAN, outcome.source)
        assertTrue(outcome.pendingPlan.isEmpty())
        assertEquals(ErrorCodes.MODEL, outcome.error?.code)
        assertEquals(0, harness.policy.calls)
        assertEquals(0, harness.device.observed)
    }

    @Test
    fun an_unavailable_surface_stops_the_turn_and_the_model_is_not_asked() = runBlocking {
        val harness = Harness(screens = listOf(labelled("Settings")))

        val outcome = harness.runner.run(
            harness.request(
                "Turn on Wi-Fi",
                surfaceAvailable = false,
                surfaceError = "accessibility is off",
            ),
        )

        assertEquals(TurnSource.UNAVAILABLE, outcome.source)
        assertEquals(ErrorCodes.DEVICE, outcome.error?.code)
        assertEquals("accessibility is off", outcome.surfaceError)
        assertEquals(0, harness.policy.calls)
        assertEquals(0, harness.device.observed)
    }

    @Test
    fun a_stored_recipe_runs_without_the_model() = runBlocking {
        val store = store()
        store.save(
            goal = "Turn on Wi-Fi",
            steps = listOf(
                Action(kind = "ui.launch", app = SETTINGS),
                Action(kind = "ui.tap", ref = "e1"),
            ),
            anchors = listOf("", "TextView|text=wi-fi|id=android:id/title"),
        )
        val harness = Harness(screens = listOf(labelled("Wi-Fi")), store = store)

        val outcome = harness.runner.run(harness.request("Turn on Wi-Fi"))

        assertEquals(TurnSource.RECIPE, outcome.source)
        assertEquals(2, outcome.replaySteps.size)
        assertEquals(0, harness.policy.calls)
        assertEquals(listOf(SETTINGS), harness.device.launches)
        assertEquals(listOf("e1"), harness.device.taps)
        assertTrue(outcome.answer.startsWith("Repeated the 2 steps"))
    }

    @Test
    fun a_model_turn_is_answered_and_its_steps_are_saved() = runBlocking {
        val store = store()
        val harness = Harness(
            screens = listOf(labelled("Wi-Fi"), labelled("Wi-Fi on")),
            replies = listOf(
                """{"kind":"ui.tap","ref":"e1"}""",
                """{"say":"Wi-Fi is on.","done":true,"needUser":false}""",
            ),
            store = store,
        )

        val outcome = harness.runner.run(harness.request("Turn on Wi-Fi"))

        assertEquals(TurnSource.MODEL, outcome.source)
        assertEquals("Wi-Fi is on.", outcome.answer)
        assertEquals(1, outcome.executed)
        assertEquals(1, outcome.verified)
        assertTrue(outcome.recipeSaved)
        assertEquals("test", outcome.knowledgeVersion)
        val recipe = store.find("Turn on Wi-Fi")
        assertEquals(1, recipe?.steps?.size)
        assertEquals("TextView|text=wi-fi|id=android:id/title", recipe?.anchorAt(0))
    }

    @Test
    fun an_invalid_step_is_reported_and_nothing_is_saved() = runBlocking {
        val store = store()
        val harness = Harness(
            screens = listOf(labelled("Wi-Fi")),
            replies = listOf("""{"kind":"ui.tap"}"""),
            store = store,
        )

        val outcome = harness.runner.run(harness.request("Tap something"))

        assertEquals(ErrorCodes.SCHEMA, outcome.error?.code)
        assertTrue(outcome.records.isEmpty())
        assertFalse(outcome.recipeSaved)
        assertNull(store.find("Tap something"))
    }

    @Test
    fun a_met_checkpoint_lets_the_recipe_be_saved() = runBlocking {
        val store = store()
        val harness = Harness(
            screens = listOf(labelled("Wi-Fi"), labelled("Wi-Fi on")),
            replies = listOf(
                """{"kind":"ui.tap","ref":"e1"}""",
                """{"say":"Wi-Fi is on.","done":true,"needUser":false}""",
            ),
            store = store,
        )

        val outcome = harness.runner.run(
            harness.request("Turn on Wi-Fi", checkpoints = listOf(Checkpoint("Wi-Fi on"))),
        )

        assertTrue(outcome.checkpoints?.complete == true)
        assertTrue(outcome.recipeSaved)
    }

    @Test
    fun a_missing_checkpoint_keeps_the_recipe_out_of_the_store() = runBlocking {
        val store = store()
        val harness = Harness(
            screens = listOf(labelled("Wi-Fi"), labelled("Wi-Fi on")),
            replies = listOf(
                """{"kind":"ui.tap","ref":"e1"}""",
                """{"say":"Wi-Fi is on.","done":true,"needUser":false}""",
            ),
            store = store,
        )

        val outcome = harness.runner.run(
            harness.request("Turn on Wi-Fi", checkpoints = listOf(Checkpoint("Bluetooth"))),
        )

        assertFalse(outcome.checkpoints?.complete == true)
        assertFalse(outcome.recipeSaved)
        assertNull(store.find("Turn on Wi-Fi"))
    }

    @Test
    fun a_tap_on_a_label_less_node_is_not_stored_as_a_recipe() = runBlocking {
        val store = store()
        val harness = Harness(
            screens = listOf(
                observation(
                    ObservationNode(ref = "e1", type = "View"),
                    ObservationNode(ref = "e2", type = "TextView", text = "Settings"),
                ),
                observation(
                    ObservationNode(ref = "e1", type = "View"),
                    ObservationNode(ref = "e2", type = "TextView", text = "Settings opened"),
                ),
            ),
            replies = listOf(
                """{"kind":"ui.tap","ref":"e1"}""",
                """{"say":"Opened.","done":true,"needUser":false}""",
            ),
            store = store,
        )

        val outcome = harness.runner.run(harness.request("Open settings"))

        assertEquals(1, outcome.executed)
        assertFalse(outcome.recipeSaved)
        assertNull(store.find("Open settings"))
    }

    @Test
    fun the_classic_model_flow_is_untouched_when_decisions_are_off() = runBlocking {
        val votes = mutableListOf<DecisionRun>()
        val asking = object : DecisionLayer {
            override val metadata = LayerMetadata(
                id = "asking",
                version = "1.0.0",
                latency = LatencyClass.MICRO,
                decidesUpTo = ActionClass.DANGEROUS,
                status = LayerStatus.DEFAULT,
                conformance = ConformanceStatus.PASSED,
                author = "test",
                summary = "asks about everything",
            )

            override suspend fun decide(context: DecisionContext): LayerDecision =
                LayerDecision(Verb.ASK, "always_ask", 0.9, "asking")
        }
        val decisions = DecisionRuntime(
            coordinator = DecisionCoordinator(DecisionRegistry(listOf(asking))),
            mode = { DecisionMode.Off },
            shadow = { false },
            sink = { _, run -> votes += run },
            applies = { true },
        )
        val harness = Harness(
            screens = listOf(labelled("Settings"), labelled("Connections")),
            replies = listOf(
                """{"kind":"ui.tap","ref":"e1"}""",
                """{"say":"Done.","done":true,"needUser":false}""",
            ),
            decisions = decisions,
        )

        val outcome = harness.runner.run(harness.request("Open settings"))

        assertEquals(TurnSource.MODEL, outcome.source)
        assertEquals("Done.", outcome.answer)
        assertEquals(1, outcome.executed)
        assertEquals(listOf("e1"), harness.device.taps)
        assertEquals(0, votes.size)
    }

    @Test
    fun a_canonical_command_runs_without_the_model() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            replies = emptyList(),
            commands = true,
        )

        val outcome = harness.runner.run(harness.request("open settings"))

        assertEquals(TurnSource.COMMAND, outcome.source)
        assertEquals(listOf(SETTINGS), harness.device.launches)
        assertEquals("Opened Settings.", outcome.answer)
        assertEquals(0, harness.policy.calls)
        assertEquals(1, outcome.executed)
    }

    @Test
    fun a_known_graph_runs_without_the_model() = runBlocking {
        val step = com.hopa.decision.graph.GraphStep(
            graph = "Settings",
            node = "start",
            action = Action(kind = "ui.launch", app = SETTINGS),
            answer = "Opened Settings.",
            done = true,
        )
        val harness = Harness(
            screens = listOf(labelled("Home")),
            replies = emptyList(),
            graphs = FakeGraph(listOf(step)),
        )

        val outcome = harness.runner.run(harness.request("open settings"))

        assertEquals(TurnSource.GRAPH, outcome.source)
        assertEquals("Opened Settings.", outcome.answer)
        assertEquals(listOf(SETTINGS), harness.device.launches)
        assertEquals(0, harness.policy.calls)
    }

    @Test
    fun a_written_path_goes_before_a_command() = runBlocking {
        val clock = "com.sec.android.app.clockpackage"
        val step = com.hopa.decision.graph.GraphStep(
            graph = "Clock",
            node = "start",
            action = Action(kind = "ui.launch", app = clock),
            answer = "Opened Alarms.",
            done = true,
        )
        val harness = Harness(
            screens = listOf(labelled("Home")),
            replies = emptyList(),
            commands = true,
            graphs = FakeGraph(
                listOf(step),
                com.hopa.decision.graph.GraphTarget(clock, "Clock", completes = true),
            ),
        )

        val outcome = harness.runner.run(harness.request("open clock"))

        assertEquals(TurnSource.GRAPH, outcome.source)
        assertEquals(listOf(clock), harness.device.launches)
        assertEquals(0, harness.policy.calls)
    }

    @Test
    fun graph_only_never_answers_with_a_command() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            replies = emptyList(),
            commands = true,
            graphs = FakeGraph(emptyList()),
        )

        val outcome = harness.runner.run(
            harness.request("open settings").copy(graphFallback = false),
        )

        assertEquals(TurnSource.GRAPH, outcome.source)
        assertEquals(emptyList<String>(), harness.device.launches)
        assertEquals(0, harness.policy.calls)
    }

    @Test
    fun a_known_graph_skips_the_plan_gate() = runBlocking {
        val step = com.hopa.decision.graph.GraphStep(
            graph = "Settings",
            node = "start",
            action = Action(kind = "ui.launch", app = SETTINGS),
            answer = "Opened Settings.",
            done = true,
        )
        val harness = Harness(
            screens = listOf(labelled("Home")),
            replies = emptyList(),
            plan = listOf("Open Settings", "Tap Connections"),
            graphs = FakeGraph(
                listOf(step),
                com.hopa.decision.graph.GraphTarget(SETTINGS, "Settings", completes = true),
            ),
        )

        val outcome = harness.runner.run(harness.request("open settings", planFirst = true))

        assertEquals(TurnSource.GRAPH, outcome.source)
        assertTrue(outcome.pendingPlan.isEmpty())
        assertEquals(listOf(SETTINGS), harness.device.launches)
    }

    @Test
    fun a_graph_miss_falls_through_to_the_model() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Home")),
            replies = listOf("All done."),
            graphs = FakeGraph(emptyList()),
        )

        val outcome = harness.runner.run(harness.request("open settings"))

        assertEquals(TurnSource.MODEL, outcome.source)
        assertEquals(1, harness.policy.calls)
    }

    @Test
    fun graph_only_refuses_a_goal_without_a_written_path() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Home")),
            replies = listOf("All done."),
            graphs = FakeGraph(emptyList()),
        )

        val outcome = harness.runner.run(
            harness.request("open settings").copy(graphFallback = false),
        )

        assertEquals(TurnSource.GRAPH, outcome.source)
        assertEquals(0, harness.policy.calls)
        assertEquals(ErrorCodes.BLOCKED, outcome.error?.code)
        assertTrue(outcome.answer.contains("Auto or Model", ignoreCase = true))
    }

    @Test
    fun the_graph_path_can_be_switched_off() = runBlocking {
        val step = com.hopa.decision.graph.GraphStep(
            graph = "Settings",
            node = "start",
            action = Action(kind = "ui.launch", app = SETTINGS),
            answer = "Opened Settings.",
            done = true,
        )
        val harness = Harness(
            screens = listOf(labelled("Home")),
            replies = listOf("All done."),
            graphs = FakeGraph(listOf(step)),
        )

        val outcome = harness.runner.run(harness.request("open settings").copy(useGraphs = false))

        assertEquals(TurnSource.MODEL, outcome.source)
        assertEquals(emptyList<String>(), harness.device.launches)
    }

    @Test
    fun a_canonical_command_skips_the_plan_gate() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            replies = emptyList(),
            plan = listOf("Open Settings", "Tap Connections"),
            commands = true,
        )

        val outcome = harness.runner.run(harness.request("open settings", planFirst = true))

        assertEquals(TurnSource.COMMAND, outcome.source)
        assertEquals(listOf(SETTINGS), harness.device.launches)
        assertEquals(0, harness.policy.calls)
        assertTrue(outcome.pendingPlan.isEmpty())
    }

    @Test
    fun an_unrecognized_goal_still_uses_the_model() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            replies = listOf("All done."),
            commands = true,
        )

        val outcome = harness.runner.run(harness.request("купи хлеб"))

        assertEquals(TurnSource.MODEL, outcome.source)
        assertEquals(1, harness.policy.calls)
    }

    @Test
    fun the_command_path_can_be_switched_off() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            replies = listOf("All done."),
            commands = true,
        )

        val outcome = harness.runner.run(
            harness.request("open settings").copy(instantCommands = false),
        )

        assertEquals(TurnSource.MODEL, outcome.source)
        assertEquals(1, harness.policy.calls)
    }

    @Test
    fun back_is_a_command_too() = runBlocking {
        val harness = Harness(
            screens = listOf(labelled("Settings")),
            replies = emptyList(),
            commands = true,
        )

        val outcome = harness.runner.run(harness.request("назад"))

        assertEquals(TurnSource.COMMAND, outcome.source)
        assertEquals("ui.back", outcome.records.single().action.kind)
    }
}
