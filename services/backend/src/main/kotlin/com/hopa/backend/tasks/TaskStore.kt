package com.hopa.backend.tasks

import java.util.concurrent.ConcurrentHashMap
import kotlinx.serialization.json.JsonObject

/**
 * One task as the backend sees it: an identified message, its route, and the
 * durable state a reconnect resumes from.
 */
data class TaskRecord(
    val id: String,
    val householdId: String,
    val memberId: String,
    val from: String,
    val to: String,
    val messageId: String,
    val trace: String,
    val ts: Long,
    val body: JsonObject,
    val state: String,
    val deadlineAt: Long,
)

interface TaskStore {
    fun remember(householdId: String, messageId: String, task: TaskRecord)

    fun recall(householdId: String, messageId: String): TaskRecord?

    fun find(taskId: String, householdId: String): TaskRecord?

    fun update(task: TaskRecord)

    fun pendingFor(deviceId: String, householdId: String, now: Long): List<TaskRecord>

    fun markDelivered(taskId: String, householdId: String)

    fun event(taskId: String, householdId: String, kind: String, body: JsonObject, at: Long)
}

class InMemoryTaskStore : TaskStore {
    private val byMessage = ConcurrentHashMap<String, TaskRecord>()
    private val byId = ConcurrentHashMap<String, TaskRecord>()

    override fun remember(householdId: String, messageId: String, task: TaskRecord) {
        byMessage[key(householdId, messageId)] = task
        byId[task.id] = task
    }

    override fun recall(householdId: String, messageId: String): TaskRecord? =
        byMessage[key(householdId, messageId)]

    override fun find(taskId: String, householdId: String): TaskRecord? =
        byId[taskId]?.takeIf { it.householdId == householdId }

    override fun update(task: TaskRecord) {
        byId[task.id] = task
        byMessage[key(task.householdId, task.messageId)] = task
    }

    override fun pendingFor(deviceId: String, householdId: String, now: Long): List<TaskRecord> =
        byId.values
            .filter {
                it.to == deviceId &&
                    it.householdId == householdId &&
                    it.state in setOf("queued", "delivered") &&
                    it.deadlineAt > now
            }
            .sortedBy { it.ts }

    override fun markDelivered(taskId: String, householdId: String) {
        byId[taskId]?.let { update(it.copy(state = "delivered")) }
    }

    override fun event(taskId: String, householdId: String, kind: String, body: JsonObject, at: Long) {
        // The in-memory store exists for the protocol tests; the event log is durable.
    }

    private fun key(householdId: String, messageId: String) = "$householdId/$messageId"
}
