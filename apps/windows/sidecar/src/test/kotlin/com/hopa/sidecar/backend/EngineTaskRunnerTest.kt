package com.hopa.sidecar.backend

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

import com.hopa.sidecar.engine.Engine

/**
 * The Engine adapter receives turns through Engine's `onTurnEnd` hook (R31).
 * It is built from lambdas so the test needs no model or host.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EngineTaskRunnerTest {
    @Test
    fun `a turn starts with a fresh id and resumes with the answer`() = runTest {
        var startedId = ""
        var startedGoal = ""
        val runner = EngineTaskRunner(
            startTurn = { id, goal ->
                startedId = id
                startedGoal = goal
            },
            newId = { "turn-1" },
        )

        val answer = async { runner.run("open settings") }
        runCurrent()

        assertEquals("turn-1", startedId)
        assertEquals("open settings", startedGoal)

        runner.complete(startedId, "opened settings")
        assertEquals("opened settings", answer.await())
    }

    @Test
    fun `cancelling the caller cancels only its own engine turn`() = runTest {
        var cancelled: String? = null
        var started = false
        val runner = EngineTaskRunner(
            startTurn = { _, _ -> started = true },
            cancelTurn = { id -> cancelled = id },
            newId = { "turn-2" },
        )

        val job = launch { runner.run("open settings") }
        runCurrent()
        assertTrue(started)

        job.cancel()
        runCurrent()

        assertEquals("turn-2", cancelled)
    }

    @Test
    fun `an end hook for an unknown turn is ignored`() = runTest {
        var started = false
        val runner = EngineTaskRunner(
            startTurn = { _, _ -> started = true },
            newId = { "turn-3" },
        )

        val answer = async { runner.run("open settings") }
        runCurrent()
        assertTrue(started)

        runner.complete("some-other-turn", "wrong")
        runner.complete("turn-3", "right")

        assertEquals("right", answer.await())
    }

    @Test
    fun `a second complete does not overwrite the first answer`() = runTest {
        val runner = EngineTaskRunner(startTurn = { _, _ -> }, newId = { "turn-1" })

        val answer = async { runner.run("open settings") }
        runCurrent()

        runner.complete("turn-1", "first")
        runner.complete("turn-1", "second")

        assertEquals("first", answer.await())
    }

    @Test
    fun `two runs are serialized one engine turn at a time`() = runTest {
        val started = mutableListOf<String>()
        var next = 0
        val runner = EngineTaskRunner(
            startTurn = { id, _ -> started += id },
            newId = { "turn-${++next}" },
        )

        val first = async { runner.run("first") }
        val second = async { runner.run("second") }
        runCurrent()
        assertEquals(listOf("turn-1"), started)

        runner.complete("turn-1", "one")
        runCurrent()
        assertEquals(listOf("turn-1", "turn-2"), started)

        runner.complete("turn-2", "two")
        assertEquals("one", first.await())
        assertEquals("two", second.await())
    }

    @Test
    fun `a start that throws fails the run and releases the queue`() = runTest {
        var attempts = 0
        var next = 0
        val runner = EngineTaskRunner(
            startTurn = { _, _ ->
                attempts++
                if (attempts == 1) throw IllegalStateException("no model")
            },
            newId = { "turn-${++next}" },
        )

        val failed = async { runCatching { runner.run("first") } }
        runCurrent()
        assertTrue(failed.await().isFailure)

        val second = async { runner.run("second") }
        runCurrent()
        assertEquals(2, attempts)

        runner.complete("turn-2", "recovered")
        assertEquals("recovered", second.await())
    }

    @Test
    fun `a turn that never ends times out and releases the queue`() = runTest {
        var next = 0
        var cancelled: String? = null
        val runner = EngineTaskRunner(
            startTurn = { _, _ -> },
            cancelTurn = { id -> cancelled = id },
            newId = { "turn-${++next}" },
            turnTimeoutMs = 1_000,
        )

        val timedOut = async { runCatching { runner.run("slow") } }
        runCurrent()
        advanceTimeBy(1_001)
        runCurrent()

        assertTrue(timedOut.await().isFailure)
        assertEquals("turn-1", cancelled)

        val second = async { runner.run("next") }
        runCurrent()
        runner.complete("turn-2", "after timeout")
        assertEquals("after timeout", second.await())
    }
}
