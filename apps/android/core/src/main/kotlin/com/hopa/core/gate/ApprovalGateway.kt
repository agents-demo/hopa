package com.hopa.core.gate

interface ApprovalGateway {
    suspend fun approve(request: ApprovalRequest): Boolean
}
