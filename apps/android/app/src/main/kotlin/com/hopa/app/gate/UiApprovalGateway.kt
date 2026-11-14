package com.hopa.app.gate

import com.hopa.core.gate.ApprovalGateway
import com.hopa.core.gate.ApprovalRequest
import com.hopa.data.approvals.PendingApprovalStore
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The approval question: shown in the sheet, persisted while it waits, denied
 * when nobody answers in time. A question found on disk at startup means the
 * process died while waiting; the app clears it instead of resurrecting it.
 */
class UiApprovalGateway(
    private val store: PendingApprovalStore? = null,
    private val timeoutMillis: Long = 120_000,
) : ApprovalGateway {
    private val _pending = MutableStateFlow<ApprovalRequest?>(null)
    val pending: StateFlow<ApprovalRequest?> = _pending.asStateFlow()
    private var deferred: CompletableDeferred<Boolean>? = null

    override suspend fun approve(request: ApprovalRequest): Boolean {
        val answer = CompletableDeferred<Boolean>()
        deferred = answer
        _pending.value = request
        runCatching { store?.save(request) }
        return try {
            withTimeoutOrNull(timeoutMillis) { answer.await() } ?: false
        } finally {
            _pending.value = null
            deferred = null
            runCatching { store?.clear() }
        }
    }

    fun resolve(allow: Boolean) {
        deferred?.complete(allow)
    }
}
