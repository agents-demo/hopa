package com.hopa.sidecar.protocol.handlers

import com.hopa.sidecar.approval.HostApproval
import com.hopa.sidecar.config.RuntimeConfig
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.support.Stdio
import kotlinx.serialization.json.JsonObject

/**
 * An approval answered by a device. ADR-0024: a phone answer cannot be trusted
 * when no phone link exists — there is no path for the phone to have answered,
 * so it is refused instead of believed (fail closed).
 */
internal class ApprovalHandler(
    private val io: Stdio,
    private val approval: HostApproval,
    private val config: RuntimeConfig,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (type != "approval.result") return false
        val id = message.text("id")
        val claimed = message.text("device").ifBlank { "pc" }
        val allow = message.text("allow").toBoolean()
        if (claimed == "phone" && !config.hasPhoneLink) {
            io.log("refused an approval claiming the phone: no phone link is attached")
            approval.resolve(id, false, "pc")
        } else {
            approval.resolve(id, allow, claimed)
        }
        return true
    }
}
