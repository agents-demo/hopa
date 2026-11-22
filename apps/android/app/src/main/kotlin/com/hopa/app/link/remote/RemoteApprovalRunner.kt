package com.hopa.app.link.remote

import com.hopa.backend.link.BackendLink
import com.hopa.backend.wire.BackendEnvelope
import com.hopa.backend.wire.BackendReplies
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.json.HopaJson
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.JsonObject

/**
 * Shows an approval asked for by another device and sends the answer back.
 *
 * The request is a `task.needs_approval` frame from the PC. It never runs a
 * goal and never touches the screen: the person's decision is the whole task.
 * The socket stays open while the sheet waits, and a timeout is a denial.
 */
class RemoteApprovalRunner(
    private val deviceId: () -> String,
    private val link: () -> BackendLink?,
    private val approval: ApprovalGateway,
    private val foreground: () -> Boolean,
    private val postApproval: () -> Unit,
    private val taskStarted: () -> Unit = {},
    private val taskFinished: () -> Unit = {},
    private val timeoutMillis: Long = 90_000,
) {
    private val gate = Mutex()

    suspend fun handle(task: BackendEnvelope) {
        val live = link() ?: return
        // Ack first: a locked or busy phone still has to tell the PC the
        // request arrived before it starts waiting for a person.
        live.ack(task)
        val id = task.task.orEmpty().trim()
        val payload = task.body["approval"] as? JsonObject
        val request = payload?.let(::decode)
        if (id.isBlank() || request == null) {
            live.send(
                BackendReplies.error(
                    task,
                    deviceId(),
                    "E_SCHEMA",
                    "the approval request had no task id or no approval body",
                    false,
                ),
            )
            return
        }

        gate.withLock {
            taskStarted()
            try {
                if (!foreground()) {
                    // The sheet can only be answered in HOPA; the notification
                    // is the way back to it while another app is in front.
                    runCatching { postApproval() }
                }
                val allow = try {
                    withTimeoutOrNull(timeoutMillis) { approval.approve(request) } ?: false
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    false
                }
                live.send(BackendReplies.approval(task, deviceId(), allow))
            } finally {
                taskFinished()
            }
        }
    }

    private fun decode(payload: JsonObject): ApprovalRequest? = runCatching {
        HopaJson.element.decodeFromJsonElement(ApprovalRequest.serializer(), payload)
    }.getOrNull()
}
