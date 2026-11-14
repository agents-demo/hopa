package com.hopa.core.testing

import com.hopa.core.gate.ApprovalGateway
import com.hopa.core.gate.ApprovalRequest

/** Answers every approval the same way and counts the questions. */
class FakeApproval(
    var allow: Boolean = false,
) : ApprovalGateway {
    var asked = 0

    override suspend fun approve(request: ApprovalRequest): Boolean {
        asked += 1
        return allow
    }
}
