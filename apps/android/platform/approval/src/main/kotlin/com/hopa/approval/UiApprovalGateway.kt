package com.hopa.approval

import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.stores.PendingApprovalStore
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The approval question: shown in the sheet, persisted while it waits, denied when
 * nobody answers in time. One question at a time - parallel tasks queue here, so
 * two runs cannot overwrite each other's sheet or answer for one another.
 */
class UiApprovalGateway(
    private val store: PendingApprovalStore? = null,
    private val timeoutMillis: Long = 120_000,
) : ApprovalGateway {
    private val _pending = MutableStateFlow<ApprovalRequest?>(null)
    val pending: StateFlow<ApprovalRequest?> = _pending.asStateFlow()
    private var deferred: CompletableDeferred<Boolean>? = null
    private val oneAtATime = Mutex()

    override suspend fun approve(request: ApprovalRequest): Boolean = oneAtATime.withLock {
        val answer = CompletableDeferred<Boolean>()
        deferred = answer
        _pending.value = request
        runCatching { store?.save(request) }
        try {
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
