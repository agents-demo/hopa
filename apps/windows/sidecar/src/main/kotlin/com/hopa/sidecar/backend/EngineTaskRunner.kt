package com.hopa.sidecar.backend

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import com.hopa.sidecar.turn.TurnEngine

/**
 * Adapts the engine's fire-and-forget turns to the gateway's
 * `suspend (goal) -> answer` (R31).
 *
 * [run] starts one turn under a fresh id and suspends until the engine calls
 * [complete] from its `onTurnEnd` hook. Cancelling the caller cancels the
 * engine's current turn. The lambdas keep the adapter testable without a
 * model; production supplies `engine.startTurn` and `engine.onTurnEnd`.
 *
 * The runner still keeps its own lock even though `TurnEngine.startTurn` now holds
 * a turn gate too: the runner's lock is also its pending-turn bookkeeping, and
 * a second `task.create` must not queue a second engine turn just to wait.
 * The engine gate is the one that serializes host and backend turns. Each turn
 * is bounded by [turnTimeoutMs] so a lost `onTurnEnd` releases the queue
 * instead of wedging it.
 */
class EngineTaskRunner(
    private val startTurn: (id: String, goal: String) -> Unit,
    private val cancelTurn: (id: String) -> Unit = {},
    private val newId: () -> String = { UUID.randomUUID().toString() },
    private val turnTimeoutMs: Long = TURN_TIMEOUT_MS,
) {
    private val pending = ConcurrentHashMap<String, PendingTurn>()
    private val turns = Mutex()

    /**
     * A turn that never ends must not wedge the queue: the wait is bounded and
     * a timeout is reported as a failure, not as cancellation.
     */
    suspend fun run(goal: String): String = turns.withLock {
        try {
            withTimeout(turnTimeoutMs) { awaitTurn(goal) }
        } catch (timedOut: TimeoutCancellationException) {
            throw IllegalStateException("the engine turn timed out", timedOut)
        }
    }

    private suspend fun awaitTurn(goal: String): String {
        val id = newId()
        val turn = PendingTurn()
        pending[id] = turn
        try {
            startTurn(id, goal)
            return suspendCancellableCoroutine { continuation ->
                continuation.invokeOnCancellation {
                    pending.remove(id)
                    cancelTurn(id)
                }
                turn.done.invokeOnCompletion { cause ->
                    if (cause == null) {
                        continuation.resume(turn.answer)
                    } else {
                        continuation.resumeWithException(cause)
                    }
                }
            }
        } catch (failed: Throwable) {
            pending.remove(id)
            throw failed
        }
    }

    /** The engine's `onTurnEnd` hook; an unknown id is ignored. */
    fun complete(id: String, answer: String) {
        val turn = pending.remove(id) ?: return
        turn.answer = answer
        turn.done.complete(Unit)
    }

    private class PendingTurn {
        val done = CompletableDeferred<Unit>()

        @Volatile
        var answer: String = ""
    }

    private companion object {
        const val TURN_TIMEOUT_MS = 10 * 60 * 1000L
    }
}
