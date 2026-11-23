package com.hopa.sidecar.approval

import com.hopa.contracts.approval.ApprovalDecision
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.store.PendingApprovals
import com.hopa.sidecar.support.Stdio

/** W2: approvals travel to the window and wait up to two minutes. */
class HostApproval(
    private val io: Stdio,
    private val store: PendingApprovals,
) : ApprovalGateway {
    private val pending = ConcurrentHashMap<String, CompletableDeferred<ApprovalDecision>>()
    private val counter = AtomicInteger(0)

    /**
     * The host answers one question. `device` is "pc" for the local window and
     * "phone" when the answer came from Android over the gateway; the record keeps it.
     */
    fun resolve(id: String, allow: Boolean, device: String = "pc") {
        pending.remove(id)?.complete(ApprovalDecision(allow, device))
    }

    override suspend fun approve(request: ApprovalRequest): Boolean = decide(request).allow

    override suspend fun decide(request: ApprovalRequest): ApprovalDecision {
        val id = "ap-${counter.incrementAndGet()}"
        val deferred = CompletableDeferred<ApprovalDecision>()
        pending[id] = deferred
        store.save(id, request)
        io.send(Protocol.approvalRequest(id, request))
        // A missing or late answer is a deny from the PC side (protocol v1).
        val answer = withTimeoutOrNull(120_000) { deferred.await() }
            ?: ApprovalDecision(false, "pc")
        store.clear(id)
        return answer
    }
}
