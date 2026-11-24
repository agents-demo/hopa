package com.hopa.sidecar.turn

import com.hopa.agent.recipe.RecipeStore
import com.hopa.sidecar.approval.HostApproval
import com.hopa.sidecar.device.HeadlessDevice
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.MemoryFileStore
import com.hopa.sidecar.store.PendingApprovals
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.store.SkillFileStore
import java.nio.file.Files
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** P5: a turn can hand the foreground over before its first step. */
class TurnTakeoverTest {
    @Test
    fun `a turn that starts paused does not end until resume`() = runBlocking {
        val engine = engine()
        val ended = CompletableDeferred<String>()
        engine.onTurnEnd = { _, answer -> ended.complete(answer) }

        engine.startTurn("turn-p1", "say hello", conversationId = null, startPaused = true)
        delay(300)
        assertFalse(ended.isCompleted, "the turn ended before the person resumed")

        engine.resume()
        val answer = withTimeout(5_000) { ended.await() }
        assertTrue(answer.isNotEmpty())
    }

    private fun engine(): TurnEngine {
        val directory = Files.createTempDirectory("hopa-turn-takeover")
        val io = Stdio()
        return TurnEngine(
            io = io,
            hostDevice = HeadlessDevice(),
            approval = HostApproval(io, PendingApprovals(directory.resolve("approvals.json"))),
            store = ChatStore(directory.resolve("conversations.json")),
            recordStore = RecordStore(directory.resolve("records.json")),
            config = RuntimeConfig(),
            memory = MemoryFileStore(directory.resolve("memory.json")),
            skills = SkillFileStore(directory.resolve("skills.json")),
            recipes = RecipeStore(directory.resolve("recipes.txt").toFile()),
            forceStub = true,
            deviceAttached = false,
        )
    }
}
