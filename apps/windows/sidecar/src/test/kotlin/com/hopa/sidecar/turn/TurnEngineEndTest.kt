package com.hopa.sidecar.turn

import java.nio.file.Files
import java.nio.file.Path
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test

import com.hopa.sidecar.approval.HostApproval
import com.hopa.sidecar.device.HostDevice
import com.hopa.agent.recipe.RecipeStore
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.MemoryFileStore
import com.hopa.sidecar.store.PendingApprovals
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.store.SkillFileStore
import com.hopa.sidecar.protocol.Stdio

/**
 * The engine's end hook is the gateway's only way out of a turn, so it must
 * fire once even when the turn fails before `turn.end` (R31, Important 2).
 * [TurnEngine.guardedTurn] is the failure seam; no model or host is started.
 */
class TurnEngineEndTest {
    @Test
    fun `a turn that throws before its end still fires the hook exactly once`() = runBlocking {
        val engine = engine()
        val ends = mutableListOf<Pair<String, String>>()
        engine.onTurnEnd = { id, answer -> ends += id to answer }

        engine.guardedTurn("turn-1") { throw IllegalStateException("store exploded with goal text") }

        assertEquals(1, ends.size)
        assertEquals("turn-1", ends.single().first)
        assertFalse(ends.single().second.contains("store exploded"))
    }

    @Test
    fun `a second turn waits for the gate instead of running beside the first`() = runBlocking {
        val engine = engine()
        val order = mutableListOf<String>()
        val firstStarted = CompletableDeferred<Unit>()
        val releaseFirst = CompletableDeferred<Unit>()
        val secondStarted = CompletableDeferred<Unit>()

        val first = launch {
            engine.runSerialized("turn-a") {
                firstStarted.complete(Unit)
                releaseFirst.await()
                order += "a"
                "a"
            }
        }
        firstStarted.await()
        val second = launch {
            engine.runSerialized("turn-b") {
                order += "b"
                secondStarted.complete(Unit)
                "b"
            }
        }
        delay(100)
        assertFalse(secondStarted.isCompleted, "the second turn ran before the first released the gate")

        releaseFirst.complete(Unit)
        first.join()
        second.join()

        assertEquals(listOf("a", "b"), order)
    }

    @Test
    fun `a successful turn fires the hook once with its answer`() = runBlocking {
        val engine = engine()
        val ends = mutableListOf<Pair<String, String>>()
        engine.onTurnEnd = { id, answer -> ends += id to answer }

        engine.guardedTurn("turn-2") { "opened settings" }

        assertEquals(listOf("turn-2" to "opened settings"), ends)
    }

    private fun engine(): TurnEngine {
        val directory: Path = Files.createTempDirectory("hopa-engine-turn-end")
        val io = Stdio()
        return TurnEngine(
            io = io,
            hostDevice = HostDevice(io),
            approval = HostApproval(io, PendingApprovals(directory.resolve("approvals.json"))),
            store = ChatStore(directory.resolve("conversations.json")),
            recordStore = RecordStore(directory.resolve("records.json")),
            config = RuntimeConfig(),
            memory = MemoryFileStore(directory.resolve("memory.json")),
            skills = SkillFileStore(directory.resolve("skills.json")),
            recipes = RecipeStore(directory.resolve("recipes.txt").toFile()),
        )
    }
}
