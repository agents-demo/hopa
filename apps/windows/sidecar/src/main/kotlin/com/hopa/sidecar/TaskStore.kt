package com.hopa.sidecar

import com.hopa.contracts.wire.Approver
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * P4: a local *view* of gateway tasks (ADR-0024). The backend's Postgres task
 * store is authoritative; this mirror holds only what the host has received
 * over the gateway so the rail and the turn can read it.
 *
 * States and event names are the gateway's, not a second state machine:
 * `queued -> delivered -> acked -> progress -> done|failed|cancelled`.
 * `from`/`to` are local labels (pc/phone) mapped from the backend's
 * `platform`/`deviceId`; a client never names another device itself.
 */
data class TaskEvent(
    val index: Int,
    val type: String,
    val from: String,
    val at: Long,
)

data class HandoffTask(
    val id: String,
    val goal: String,
    val state: String,
    val from: String = "pc",
    val to: String? = null,
    val events: List<TaskEvent> = emptyList(),
    val postconditions: List<String> = emptyList(),
    val approver: Approver? = null,
    val error: String? = null,
) {
    init {
        require(state in STATES) { "unknown gateway task state: $state" }
        require(from == "pc" || from == "phone") { "task from must be pc or phone" }
        require(to == null || to == "pc" || to == "phone") { "task to must be pc or phone" }
        require(events.all { it.type in EVENTS }) { "unknown gateway task event" }
        require(events.all { it.from == "pc" || it.from == "phone" }) {
            "event from must be pc or phone"
        }
    }

    companion object {
        val STATES = setOf(
            "queued", "delivered", "acked", "progress", "needs_approval",
            "done", "failed", "cancelled",
        )
        val EVENTS = setOf(
            "task.create", "task.needs_approval", "deliver", "task.ack", "task.progress",
            "task.result", "task.error", "task.cancel",
        )
    }
}

class TaskStore {
    private val tasks = ConcurrentHashMap<String, HandoffTask>()
    private val counter = AtomicInteger(0)

    /** Mirror a locally created task. The backend assigns the real task id. */
    fun create(id: String, goal: String, from: String = "pc"): HandoffTask {
        val key = id.ifBlank { "t-${counter.incrementAndGet()}" }
        val task = HandoffTask(
            id = key,
            goal = goal,
            state = "queued",
            from = from,
            events = listOf(TaskEvent(index = 0, type = "task.create", from = from, at = now())),
        )
        tasks[key] = task
        return task
    }

    fun get(taskId: String): HandoffTask? = tasks[taskId]

    fun list(): List<HandoffTask> = tasks.values.sortedBy { it.id }

    /**
     * Record the gateway target. The host sends `task.create` to the backend;
     * this side only records where it went, and waits for a `deliver` event.
     */
    fun handoff(taskId: String, to: String): HandoffTask? {
        val task = tasks[taskId] ?: return null
        require(to == "pc" || to == "phone") { "handoff target must be pc or phone" }
        val moved = task.copy(to = to, error = null)
        tasks[taskId] = moved
        return moved
    }

    /**
     * Apply one gateway event. State transitions match TaskRouter.kt:215–221.
     * The sender label comes from the authenticated gateway message, not from
     * a claim in the body (ADR-0024).
     */
    fun apply(
        taskId: String,
        type: String,
        from: String = "pc",
        at: Long = now(),
        approver: Approver? = null,
        error: String? = null,
    ): HandoffTask? {
        val task = tasks[taskId] ?: return null
        require(type in HandoffTask.EVENTS) { "unknown gateway task event: $type" }
        require(from == "pc" || from == "phone") { "event from must be pc or phone" }
        val state = when (type) {
            "task.create" -> "queued"
            "task.needs_approval" -> "needs_approval"
            "deliver" -> "delivered"
            "task.ack" -> "acked"
            "task.progress" -> "progress"
            "task.result" -> "done"
            "task.error" -> "failed"
            "task.cancel" -> "cancelled"
            else -> task.state
        }
        val event = TaskEvent(index = task.events.size, type = type, from = from, at = at)
        val updated = task.copy(
            state = state,
            events = task.events + event,
            approver = approver ?: task.approver,
            error = if (type == "task.error") error ?: "task failed" else null,
        )
        tasks[taskId] = updated
        return updated
    }

    /** A dropped link is a gateway `task.error`, never a silent success. */
    fun failLink(taskId: String, reason: String): HandoffTask? = apply(
        taskId = taskId,
        type = "task.error",
        error = "the link was dropped: $reason; the conversation is kept",
    )

    private fun now(): Long = System.currentTimeMillis()
}
