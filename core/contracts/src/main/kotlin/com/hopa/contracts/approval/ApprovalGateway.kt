package com.hopa.contracts.approval

interface ApprovalGateway {
    suspend fun approve(request: ApprovalRequest): Boolean

    /**
     * The same answer plus the device that gave it. The default wraps [approve]
     * as a PC answer, so any gateway that has not been taught about the phone
     * (Android, headless, tests) keeps its existing behaviour.
     */
    suspend fun decide(request: ApprovalRequest): ApprovalDecision =
        ApprovalDecision(approve(request))
}
