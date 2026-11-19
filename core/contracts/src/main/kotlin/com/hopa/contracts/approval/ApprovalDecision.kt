package com.hopa.contracts.approval

/**
 * An approval answer with its source. The device is "pc" or "phone"; a gateway
 * that cannot say defaults to "pc", which keeps every existing client correct.
 * P4 needs the source to write `approver` on the record (ADR-0023).
 */
data class ApprovalDecision(
    val allow: Boolean,
    val device: String = "pc",
) {
    init {
        require(device == "pc" || device == "phone") { "approval device must be pc or phone" }
    }
}
