package com.hopa.app.gate

import com.hopa.core.gate.ApprovalGateway
import com.hopa.core.gate.ApprovalRequest
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class UiApprovalGateway : ApprovalGateway {
    private val _pending = MutableStateFlow<ApprovalRequest?>(null)
    val pending: StateFlow<ApprovalRequest?> = _pending.asStateFlow()
    private var deferred: CompletableDeferred<Boolean>? = null

    override suspend fun approve(request: ApprovalRequest): Boolean {
        val answer = CompletableDeferred<Boolean>()
        deferred = answer
        _pending.value = request
        return try {
            answer.await()
        } finally {
            _pending.value = null
            deferred = null
        }
    }

    fun resolve(allow: Boolean) {
        deferred?.complete(allow)
    }
}
