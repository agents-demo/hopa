package com.hopa.sidecar

import com.hopa.core.gate.ApprovalGateway
import com.hopa.core.gate.ApprovalRequest

/** The spike has no UI for approvals yet; W2 replaces this with the sheet. */
class SpikeApproval : ApprovalGateway {
    override suspend fun approve(request: ApprovalRequest): Boolean = true
}
