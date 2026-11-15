package com.hopa.backend.tasks

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.gateway.DeviceRegistry
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.protocol.EnvelopeValidator
import com.hopa.backend.protocol.GatewayCodec
import com.hopa.backend.protocol.GatewayError
import java.util.UUID

/** Every paired device, online or not. Production resolves from Postgres. */
fun interface DeviceDirectory {
    fun lookup(deviceId: String): DeviceIdentity?

    companion object {
        val Empty = DeviceDirectory { null }
    }
}

sealed interface RouteResult {
    data class Accepted(val task: TaskRecord, val duplicate: Boolean) : RouteResult

    data class Refused(val error: GatewayError, val trace: String?) : RouteResult
}

/**
 * Routes one message. Idempotency is checked first, tenancy second: a replayed
 * message never re-routes, and a target outside the household is refused before
 * any row is written.
 */
class TaskRouter(
    private val store: TaskStore,
    private val registry: DeviceRegistry,
    private val devices: DeviceDirectory,
    private val newTaskId: () -> String = { "tsk_" + UUID.randomUUID().toString().replace("-", "") },
    private val now: () -> Long = System::currentTimeMillis,
) {
    private val deadlineMs = 10 * 60 * 1000L

    fun route(identity: DeviceIdentity, envelope: Envelope): RouteResult {
        store.recall(identity.householdId, envelope.id)?.let { replayed ->
            return RouteResult.Accepted(replayed, duplicate = true)
        }

        return when (envelope.type) {
            "task.create" -> create(identity, envelope)
            "task.ack", "task.progress", "task.result", "task.error", "task.cancel" ->
                relay(identity, envelope)

            else -> RouteResult.Refused(
                GatewayError("E_UNSUPPORTED", "not routable in v0: ${envelope.type}"),
                envelope.trace,
            )
        }
    }

    /** Deliveries owed to a device that just came online. */
    fun deliverQueued(deviceId: String): List<TaskRecord> {
        val due = store.queuedFor(deviceId, now())
        due.forEach { task ->
            deliver(task)
            store.markDelivered(task.id)
        }
        return due
    }

    private fun create(identity: DeviceIdentity, envelope: Envelope): RouteResult {
        val to = envelope.to
            ?: return RouteResult.Refused(GatewayError("E_SCHEMA", "a task needs a target"), envelope.trace)

        val target = devices.lookup(to)
            ?: return RouteResult.Refused(GatewayError("E_TENANT", "no such device in this household"), envelope.trace)
        if (target.householdId != identity.householdId) {
            return RouteResult.Refused(GatewayError("E_TENANT", "no such device in this household"), envelope.trace)
        }

        val online = registry.online(to)
        val task = TaskRecord(
            id = newTaskId(),
            householdId = identity.householdId,
            from = identity.deviceId,
            to = to,
            messageId = envelope.id,
            trace = EnvelopeValidator.traceOf(envelope),
            ts = envelope.ts,
            body = envelope.body,
            state = if (online) "delivered" else "queued",
            deadlineAt = now() + deadlineMs,
        )
        store.remember(identity.householdId, envelope.id, task)
        if (online) {
            deliver(task)
        }
        return RouteResult.Accepted(task, duplicate = false)
    }

    private fun relay(identity: DeviceIdentity, envelope: Envelope): RouteResult {
        val taskId = envelope.task
            ?: return RouteResult.Refused(GatewayError("E_SCHEMA", "missing task id"), envelope.trace)
        val task = store.find(taskId)
            ?: return RouteResult.Refused(GatewayError("E_SCHEMA", "unknown task"), envelope.trace)
        if (task.householdId != identity.householdId ||
            (identity.deviceId != task.from && identity.deviceId != task.to)
        ) {
            return RouteResult.Refused(GatewayError("E_TENANT", "not your task"), envelope.trace)
        }

        val other = if (identity.deviceId == task.from) task.to else task.from
        registry.sessionFor(other)?.outgoing?.trySend(
            GatewayCodec.encode(
                envelope.copy(
                    task = task.id,
                    from = identity.deviceId,
                    trace = EnvelopeValidator.traceOf(envelope),
                ),
            ),
        )

        val next = when (envelope.type) {
            "task.result" -> task.copy(state = "done")
            "task.error" -> task.copy(state = "failed")
            "task.cancel" -> task.copy(state = "cancelled")
            else -> task
        }
        if (next != task) {
            store.update(next)
        }
        return RouteResult.Accepted(next, duplicate = false)
    }

    private fun deliver(task: TaskRecord) {
        registry.sessionFor(task.to)?.outgoing?.trySend(
            GatewayCodec.encode(
                Envelope(
                    v = 1,
                    id = task.messageId,
                    type = "task.create",
                    ts = task.ts,
                    trace = task.trace,
                    from = task.from,
                    to = task.to,
                    task = task.id,
                    body = task.body,
                ),
            ),
        )
    }
}
