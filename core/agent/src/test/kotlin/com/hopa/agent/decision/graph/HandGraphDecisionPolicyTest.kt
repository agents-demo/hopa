package com.hopa.agent.decision.graph

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.agent.decision.DecisionOutcome
import com.hopa.agent.decision.DecisionPolicy
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.error.HopaError
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.ScreenSize
import com.hopa.decision.graph.GraphStep
import com.hopa.decision.graph.GraphStepSource
import com.hopa.decision.graph.GraphTarget
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The graph is a step policy now: same input as a model, same three answers.
 * These tests pin that shape so the loop can keep treating everyone the same.
 */
class HandGraphDecisionPolicyTest {
    private val screen = Observation(
        id = "obs-1",
        timestamp = 1L,
        screenSize = ScreenSize(1080, 2400),
        tree = ObservationNode(type = "root", text = "Settings"),
    )

    private val input = DecisionInput(
        context = TurnContext(goal = "open settings"),
        observation = screen,
        step = 0,
    )

    @Test
    fun no_screen_means_no_path() = runBlocking {
        val policy = HandGraphDecisionPolicy(FakeGraph(listOf(step())))

        val outcome = policy.decide(input.copy(observation = null))

        assertEquals(Decision.NoPath, outcome.decision)
    }

    @Test
    fun an_edge_becomes_one_action() = runBlocking {
        val action = Action(kind = "ui.tap", text = "Display")
        val policy = HandGraphDecisionPolicy(FakeGraph(listOf(step(action = action))))

        val outcome = policy.decide(input)

        val act = outcome.decision as Decision.Act
        assertEquals(action, act.action)
        assertNull(act.then)
    }

    @Test
    fun the_last_edge_also_ends_the_turn() = runBlocking {
        val action = Action(kind = "ui.tap", text = "Brightness")
        val policy = HandGraphDecisionPolicy(
            FakeGraph(listOf(step(action = action, answer = "Brightness is open.", done = true))),
        )

        val outcome = policy.decide(input)

        val act = outcome.decision as Decision.Act
        assertEquals("Brightness is open.", act.then)
    }

    @Test
    fun nothing_to_do_means_no_path() = runBlocking {
        val policy = HandGraphDecisionPolicy(FakeGraph(emptyList()))

        assertEquals(Decision.NoPath, policy.decide(input).decision)
    }

    @Test
    fun a_broken_graph_never_throws() = runBlocking {
        val policy = HandGraphDecisionPolicy(
            object : GraphStepSource {
                override fun next(observation: Observation, goal: String): GraphStep? =
                    error("the graph file is unreadable")

                override fun target(goal: String): GraphTarget? = null
            },
        )

        assertEquals(Decision.NoPath, policy.decide(input).decision)
    }

    @Test
    fun a_chain_takes_the_first_answer_and_skips_no_path() = runBlocking {
        val second = StubPolicy("second", Decision.Act(Action(kind = "ui.tap", text = "B")))
        val chain = ChainDecisionPolicy(listOf(StubPolicy("first", Decision.NoPath), second))

        val outcome = chain.decide(input)

        val act = outcome.decision as Decision.Act
        assertEquals("B", act.action.text)
        assertEquals("first/second", chain.name)
    }

    @Test
    fun a_failure_stops_the_chain_instead_of_falling_through() = runBlocking {
        val failed = Decision.Failed(HopaError(ErrorCodes.MODEL, "no provider"))
        var secondCalls = 0
        val second = object : DecisionPolicy {
            override val name = "second"

            override suspend fun decide(input: DecisionInput): DecisionOutcome {
                secondCalls += 1
                return DecisionOutcome(Decision.Say("should not run"))
            }
        }

        val outcome = ChainDecisionPolicy(listOf(StubPolicy("first", failed), second)).decide(input)

        assertTrue(outcome.decision is Decision.Failed)
        assertEquals(0, secondCalls)
    }

    private fun step(
        action: Action = Action(kind = "ui.tap", text = "Display"),
        answer: String = "",
        done: Boolean = false,
    ) = GraphStep(
        graph = "Settings",
        node = "home",
        action = action,
        answer = answer,
        done = done,
    )

    private class StubPolicy(
        override val name: String,
        private val decision: Decision,
    ) : DecisionPolicy {
        override suspend fun decide(input: DecisionInput): DecisionOutcome {
            return DecisionOutcome(decision)
        }
    }

    private class FakeGraph(private val steps: List<GraphStep>) : GraphStepSource {
        private var index = 0

        override fun next(observation: Observation, goal: String): GraphStep? {
            return steps.getOrNull(index++)
        }

        override fun target(goal: String): GraphTarget? = null
    }
}
