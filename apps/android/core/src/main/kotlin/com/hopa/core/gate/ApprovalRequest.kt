package com.hopa.core.gate

import com.hopa.core.contracts.Action

data class ApprovalRequest(
    val title: String,
    val body: String,
    val amount: String,
    val merchant: String,
    val consequence: String,
    val isPayment: Boolean,
    val action: Action,
)
