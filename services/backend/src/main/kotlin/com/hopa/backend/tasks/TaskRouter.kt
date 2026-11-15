package com.hopa.backend.tasks

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.gateway.DeviceRegistry
import com.hopa.backend.log.EventLog
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.protocol.EnvelopeValidator
import com.hopa.backend.protocol.GatewayCodec
import com.hopa.backend.protocol.GatewayError
import com.hopa.backend.push.PushOutcome
import com.hopa.backend.push.PushPort
import com.hopa.backend.trace.TraceIds
import com.hopa.backend.trace.TraceRecorder
import java.util.UUID
import kotlinx.serialization.json.JsonObject

/** Every paired device, online or not. Production resolves from Postgres. */
interface DeviceDirectory {
    fun lookup(deviceId: String, householdId: String): DeviceIdentity?

    /** The FCM registration, or null when the device has none. */
    fun pushToken(deviceId: String, householdId: String): String? = null

    /** Records presence and, when present, the latest push token. */
    fun touch(deviceId: String, householdId: String, pushToken: String?, at: Long) {}

    /** An unregistered FCM token is cleared until the next hello replaces it. */
    fun clearPushToken(deviceId: String, householdId: String) {}

    companion object {
        val Empty = object : DeviceDirectory {
            override fun lookup(deviceId: String, householdId: String): DeviceIdentity? = null
        }
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
    private val log: EventLog = EventLog.None,
    private val push: PushPort = PushPort.None,
    private val traces: TraceRecorder = TraceRecorder.None,
    private val newTaskId: () -> String = { UUID.randomUUID().toString() },
    private val now: () -> Long = System::currentTimeMillis,
) {
    private val deadlineMs = 10 * 60 * 1000L

    fun route(
        identity: DeviceIdentity,
        envelope: Envelope,
        traceparent: String? = null,
    ): RouteResult {
        val trace = traceparent ?: EnvelopeValidator.traceOf(envelope)
        return traces.span(
            identity.householdId,
            traceId(trace),
            "route",
            identity.deviceId,
            envelope.task,
        ) {
            routeEnvelope(identity, envelope, trace)
        }
    }

    /** Deliveries owed to a device that just came online, or never acked one. */
    fun deliverPending(deviceId: String, householdId: String): List<TaskRecord> {
        val due = store.pendingFor(deviceId, householdId, now())
        due.forEach { task -> deliver(task) }
        return due
    }

    private fun routeEnvelope(
        identity: DeviceIdentity,
        envelope: Envelope,
        traceparent: String,
    ): RouteResult {
        store.recall(identity.householdId, envelope.id)?.let { replayed ->
            return RouteResult.Accepted(replayed, duplicate = true)
        }

        return when (envelope.type) {
            "task.create" -> create(identity, envelope, traceparent)
            "task.ack", "task.progress", "task.result", "task.error", "task.cancel" ->
                relay(identity, envelope)

            else -> RouteResult.Refused(
                GatewayError("E_UNSUPPORTED", "not routable in v0: ${envelope.type}"),
                envelope.trace,
            )
        }
    }

    private fun create(
        identity: DeviceIdentity,
        envelope: Envelope,
        traceparent: String,
    ): RouteResult {
        val to = envelope.to
            ?: return RouteResult.Refused(GatewayError("E_SCHEMA", "a task needs a target"), envelope.trace)

        val target = devices.lookup(to, identity.householdId)
        if (target == null) {
            log.event(
                "tenant_refused",
                mapOf(
                    "household_id" to identity.householdId,
                    "device_id" to identity.deviceId,
                    "to" to to,
                ),
            )
            return RouteResult.Refused(
                GatewayError("E_TENANT", "no such device in this household"),
                envelope.trace,
            )
        }

        val task = TaskRecord(
            id = newTaskId(),
            householdId = identity.householdId,
            memberId = identity.memberId,
            from = identity.deviceId,
            to = to,
            messageId = envelope.id,
            trace = traceparent,
            ts = envelope.ts,
            body = envelope.body,
            state = if (registry.online(to)) "delivered" else "queued",
            deadlineAt = now() + deadlineMs,
        )
        if (!store.remember(identity.householdId, envelope.id, task)) {
            val existing = store.recall(identity.householdId, envelope.id)
                ?: return RouteResult.Refused(
                    GatewayError("E_QUEUE", "duplicate message could not be read back"),
                    envelope.trace,
                )
            return RouteResult.Accepted(existing, duplicate = true)
        }
        store.event(task.id, identity.householdId, "create", envelope.body, now())

        val routed = if (registry.online(to)) {
            deliver(task)
        } else {
            val pushToken = devices.pushToken(to, identity.householdId)
            if (pushToken != null) {
                val outcome = traces.span(
                    identity.householdId,
                    traceId(traceparent),
                    "wake",
                    identity.deviceId,
                    task.id,
                ) {
                    push.wake(to, task.id, traceId(traceparent), pushToken)
                }
                if (outcome == PushOutcome.InvalidToken) {
                    devices.clearPushToken(to, identity.householdId)
                }
            }
            task
        }
        return RouteResult.Accepted(routed, duplicate = false)
    }

    private fun relay(identity: DeviceIdentity, envelope: Envelope): RouteResult {
        val taskId = envelope.task
            ?: return RouteResult.Refused(GatewayError("E_SCHEMA", "missing task id"), envelope.trace)
        val task = store.find(taskId, identity.householdId)
            ?: return RouteResult.Refused(GatewayError("E_SCHEMA", "unknown task"), envelope.trace)
        if (identity.deviceId != task.from && identity.deviceId != task.to) {
            return RouteResult.Refused(GatewayError("E_TENANT", "not your task"), envelope.trace)
        }

        if (envelope.type == "task.ack") {
            traces.span(
                identity.householdId,
                traceId(task.trace),
                "ack",
                identity.deviceId,
                task.id,
            ) {}
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
            "task.ack" -> task.copy(state = "acked")
            "task.progress" -> task.copy(state = "progress")
            "task.result" -> task.copy(state = "done")
            "task.error" -> task.copy(state = "failed")
            "task.cancel" -> task.copy(state = "cancelled")
            else -> task
        }
        if (next != task) {
            store.update(next)
        }
        store.event(task.id, identity.householdId, envelope.type, envelope.body, now())
        return RouteResult.Accepted(next, duplicate = false)
    }

    private fun deliver(task: TaskRecord): TaskRecord =
        traces.span(
            task.householdId,
            traceId(task.trace),
            "deliver",
            task.from,
            task.id,
        ) {
            val session = registry.sessionFor(task.to) ?: return@span task
            val sent = session.outgoing.trySend(
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
            ).isSuccess
            if (!sent) return@span task
            store.markDelivered(task.id, task.householdId)
            store.event(task.id, task.householdId, "deliver", JsonObject(emptyMap()), now())
            task.copy(state = "delivered")
        }

    private fun traceId(traceparent: String): String =
        TraceIds.traceId(traceparent) ?: TraceIds.traceId(TraceIds.newTraceparent())!!
}
