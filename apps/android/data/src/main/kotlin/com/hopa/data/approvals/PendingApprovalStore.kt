package com.hopa.data.approvals

import com.hopa.core.gate.ApprovalRequest

/** Survives a process death, so a question is never silently lost. */
interface PendingApprovalStore {
    suspend fun save(request: ApprovalRequest)

    suspend fun clear()

    suspend fun clearAll()

    suspend fun all(): List<ApprovalRequest>
}
