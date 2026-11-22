package com.hopa.contracts.approval

import com.hopa.contracts.wire.Action
import kotlinx.serialization.Serializable

@Serializable
data class ApprovalRequest(
    val title: String,
    val body: String,
    val amount: String,
    val merchant: String,
    val consequence: String,
    val isPayment: Boolean,
    val action: Action,
    /** Where the amount sits on the screen, [left, top, right, bottom]; null if unknown. */
    val highlight: List<Int>? = null,
    /** The app a "remember this app" answer applies to; null when nothing to remember. */
    val rememberPackage: String? = null,
)
