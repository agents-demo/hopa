package com.hopa.sidecar

import com.hopa.core.gate.ApprovalGateway
import com.hopa.core.gate.ApprovalRequest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull

/** W2: approvals travel to the window and wait up to two minutes. */
class HostApproval(private val io: Stdio) : ApprovalGateway {
    private val pending = ConcurrentHashMap<String, CompletableDeferred<Boolean>>()
    private val counter = AtomicInteger(0)

    fun resolve(id: String, allow: Boolean) {
        pending.remove(id)?.complete(allow)
    }

    override suspend fun approve(request: ApprovalRequest): Boolean {
        val id = "ap-${counter.incrementAndGet()}"
        val deferred = CompletableDeferred<Boolean>()
        pending[id] = deferred
        io.send(Protocol.approvalRequest(id, request))
        return withTimeoutOrNull(120_000) { deferred.await() } ?: false
    }
}
