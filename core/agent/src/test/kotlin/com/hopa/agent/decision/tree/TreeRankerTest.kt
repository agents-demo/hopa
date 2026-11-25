package com.hopa.agent.decision.tree

import com.hopa.agent.decision.Decision
import com.hopa.agent.decision.DecisionInput
import com.hopa.contracts.model.ActionScorer
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.ScreenSize
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class TreeRankerTest {

    @Test
    fun the_tree_becomes_the_candidates_the_model_was_trained_on() {
        val candidates = TreeCandidates.build("Send a message to Liat that I will be late", screen())
        val labels = candidates.map { it.label }

        assertEquals("type Search: I will be late", labels[0])
        assertEquals("click Search", labels[1])
        assertEquals("click Settings", labels[2])
        assertEquals("navigate back", labels[labels.size - 2])
        assertEquals("navigate home", labels.last())
        assertEquals("task complete done", labels[labels.size - 3])
        assertFalse(labels.any { it.contains("Privacy") }, labels.toString())
        assertTrue(TreeCandidates.summary(screen()).contains("Search | Settings"))
        assertTrue(TreeCandidates.summary(screen()).contains("Privacy"))
    }

    @Test
    fun a_clear_winner_becomes_a_tap_on_its_ref() = runBlocking {
        val policy = policy { _, _, candidates ->
            FloatArray(candidates.size) { index ->
                if (candidates[index] == "click Settings") 6f else 0f
            }
        }

        val decision = policy.decide(input()).decision

        val act = decision as Decision.Act
        assertEquals("ui.tap", act.action.kind)
        assertEquals("n2", act.action.ref)
        assertEquals(150, act.action.x)
        assertEquals(90, act.action.y)
    }

    @Test
    fun a_tie_is_not_a_decision() = runBlocking {
        val policy = policy { _, _, candidates ->
            FloatArray(candidates.size) { index -> if (index < 2) 4f else 0f }
        }

        assertTrue(policy.decide(input()).decision is Decision.NoPath)
    }

    @Test
    fun a_destructive_label_is_left_to_the_model() = runBlocking {
        val policy = policy { _, _, candidates ->
            FloatArray(candidates.size) { index ->
                if (candidates[index].startsWith("click Send")) 9f else 0f
            }
        }

        assertTrue(policy.decide(input(screen = sendScreen())).decision is Decision.NoPath)
    }

    @Test
    fun the_ranker_starts_after_the_first_step_and_hands_over() = runBlocking {
        var asked = false
        val scorer = ActionScorer { _, _, _ ->
            asked = true
            floatArrayOf(1f)
        }
        val policy = TreeRankerDecisionPolicy(scorer = { scorer })

        assertTrue(policy.decide(input(step = 0)).decision is Decision.NoPath)
        assertTrue(policy.decide(input(step = 4)).decision is Decision.NoPath)
        assertFalse(asked)
    }

    @Test
    fun disabled_or_missing_means_no_rung() = runBlocking {
        val missing = TreeRankerDecisionPolicy(scorer = { null })
        val off = TreeRankerDecisionPolicy(
            scorer = { ActionScorer { _, _, _ -> floatArrayOf(1f) } },
            enabled = { false },
        )

        assertTrue(missing.decide(input()).decision is Decision.NoPath)
        assertTrue(off.decide(input()).decision is Decision.NoPath)
    }

    @Test
    fun typing_needs_a_typing_goal() = runBlocking {
        val policy = policy { _, _, candidates ->
            FloatArray(candidates.size) { index ->
                if (candidates[index].startsWith("type Search")) 9f else 0f
            }
        }

        assertTrue(policy.decide(input(goal = "Open Settings")).decision is Decision.NoPath)
        val act = policy.decide(input(goal = "Search for privacy")).decision as Decision.Act
        assertEquals("ui.type", act.action.kind)
        assertEquals("n1", act.action.ref)
        assertEquals("Search for privacy".take(64), act.action.text)
    }

    private fun policy(scores: (String, String, List<String>) -> FloatArray): TreeRankerDecisionPolicy {
        val scorer = ActionScorer { goal, screen, candidates -> scores(goal, screen, candidates) }
        return TreeRankerDecisionPolicy(scorer = { scorer })
    }

    private fun input(goal: String = "Open Settings", screen: Observation = screen(), step: Int = 1) = DecisionInput(
        context = TurnContext(goal = goal),
        observation = screen,
        step = step,
    )

    private fun screen(): Observation {
        val search = ObservationNode(
            ref = "n1",
            type = "EditText",
            text = "Search",
            clickable = true,
            bounds = listOf(0, 0, 100, 50),
        )
        val settings = ObservationNode(
            ref = "n2",
            type = "Button",
            text = "Settings",
            clickable = true,
            bounds = listOf(0, 60, 300, 120),
        )
        val privacy = ObservationNode(
            ref = "n3",
            type = "TextView",
            text = "Privacy",
            bounds = listOf(0, 130, 300, 160),
        )
        return Observation(
            id = "screen",
            timestamp = 0,
            screenSize = ScreenSize(1080, 2400),
            tree = ObservationNode(
                type = "root",
                children = listOf(search, settings, privacy),
            ),
        )
    }

    private fun sendScreen(): Observation {
        val send = ObservationNode(
            ref = "n9",
            type = "Button",
            text = "Send",
            clickable = true,
            bounds = listOf(0, 0, 100, 50),
        )
        return Observation(
            id = "send",
            timestamp = 0,
            screenSize = ScreenSize(1080, 2400),
            tree = ObservationNode(type = "root", children = listOf(send)),
        )
    }
}
