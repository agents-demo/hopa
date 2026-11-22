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
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

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
    private val maxDeadlineMs = 24L * 60 * 60 * 1000

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

    /** How much work a device would find if it came online right now. */
    fun queuedFor(deviceId: String, householdId: String): Int =
        store.pendingFor(deviceId, householdId, now()).size

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
            "task.needs_approval" ->
                create(identity, envelope, traceparent, state = "needs_approval", event = "task.needs_approval")
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
        state: String = "",
        event: String = "create",
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
            state = state.ifEmpty { if (registry.online(to)) "delivered" else "queued" },
            deadlineAt = deadlineFrom(envelope.body),
        )
        if (!store.remember(identity.householdId, envelope.id, task)) {
            val existing = store.recall(identity.householdId, envelope.id)
                ?: return RouteResult.Refused(
                    GatewayError("E_QUEUE", "duplicate message could not be read back"),
                    envelope.trace,
                )
            return RouteResult.Accepted(existing, duplicate = true)
        }
        store.event(task.id, identity.householdId, event, envelope.body, now())

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

        val next = when (envelope.type) {
            "task.ack" -> task.copy(state = "acked")
            "task.progress" -> task.copy(state = "progress")
            "task.result" -> task.copy(
                state = if (envelope.body.approvalAllowed() == false) "failed" else "done",
            )
            "task.error" -> task.copy(state = "failed")
            "task.cancel" -> task.copy(state = "cancelled")
            else -> task
        }
        // Record before the frame leaves: an ack the sender receives must already
        // be durable, or a reconnect can see the task as undelivered and send it
        // again while the client believes it was acked.
        if (next != task) {
            store.update(next)
        }
        store.event(task.id, identity.householdId, envelope.type, envelope.body, now())

        val other = if (identity.deviceId == task.from) task.to else task.from
        val target = registry.sessionFor(other)
        val relayed = target?.outgoing?.trySend(
            GatewayCodec.encode(
                envelope.copy(
                    task = task.id,
                    from = identity.deviceId,
                    to = other,
                    // The relay joins the task's chain; a frame from a client that
                    // sent no traceparent must not start a new one.
                    trace = task.trace,
                ),
            ),
        )?.isSuccess == true
        if (!relayed && target != null) {
            // The socket is gone but still marked online; drop it so the next
            // create queues instead of vanishing into a closed channel.
            registry.leave(target)
        }

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
            // The hello catch-up runs after the hello ack, so it can see a task
            // `create` has just delivered on this same socket. Sending it again
            // would duplicate the frame; a reconnect gets a fresh session, so an
            // unacked task is still redelivered then.
            if (!session.sent.add(task.id)) return@span task
            // An approval request is its own frame type; a normal handoff is
            // still `task.create`. The state survives delivery so a reconnect
            // can send the same request again until the target acks it.
            val type = if (task.state == "needs_approval") "task.needs_approval" else "task.create"
            val sent = session.outgoing.trySend(
                GatewayCodec.encode(
                    Envelope(
                        v = 1,
                        id = task.messageId,
                        type = type,
                        ts = task.ts,
                        trace = task.trace,
                        from = task.from,
                        to = task.to,
                        task = task.id,
                        body = task.body,
                    ),
                ),
            ).isSuccess
            if (!sent) {
                // A closed socket must not stay "online": the task is still
                // queued, but the next hello is what will deliver it.
                registry.leave(session)
                return@span task
            }
            if (task.state == "needs_approval") {
                store.event(task.id, task.householdId, "deliver", JsonObject(emptyMap()), now())
                return@span task
            }
            store.markDelivered(task.id, task.householdId)
            store.event(task.id, task.householdId, "deliver", JsonObject(emptyMap()), now())
            task.copy(state = "delivered")
        }

    /** Null when the result is not an approval; false is a denial. */
    private fun JsonObject.approvalAllowed(): Boolean? =
        (this["approval"] as? JsonObject)
            ?.get("allow")
            ?.jsonPrimitive
            ?.booleanOrNull

    private fun traceId(traceparent: String): String =
        TraceIds.traceId(traceparent) ?: TraceIds.traceId(TraceIds.newTraceparent())!!

    /**
     * A sender may ask for a longer or shorter deadline in the body. Anything
     * outside (now, now + 24 h] is treated as absent rather than as an
     * undeliverable task.
     */
    private fun deadlineFrom(body: JsonObject): Long {
        val nowMs = now()
        val requested = body["deadlineAt"]?.jsonPrimitive?.longOrNull
        return if (requested != null && requested > nowMs && requested <= nowMs + maxDeadlineMs) {
            requested
        } else {
            nowMs + deadlineMs
        }
    }
}
