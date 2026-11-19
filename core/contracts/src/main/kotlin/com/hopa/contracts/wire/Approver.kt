package com.hopa.contracts.wire

import kotlinx.serialization.Serializable

/**
 * Who answered an approval, and when. P4 pushes approvals to the phone, so the
 * record must name the device that actually approved; a token is not an
 * identity (ADR-0023). `device` is "pc" or "phone".
 */
@Serializable
data class Approver(
    val device: String,
    val at: Long,
) {
    init {
        require(device == "pc" || device == "phone") { "approver device must be pc or phone" }
    }

    companion object {
        /** The gateway's platform label maps to the stable record label (ADR-0023). */
        fun fromPlatform(platform: String): Approver = Approver(
            device = when (platform.lowercase()) {
                "windows" -> "pc"
                "android" -> "phone"
                else -> throw IllegalArgumentException("unknown platform: $platform")
            },
            at = System.currentTimeMillis(),
        )
    }
}
