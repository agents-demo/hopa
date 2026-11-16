package com.hopa.sidecar

import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.ApprovalRequest
import java.util.concurrent.atomic.AtomicInteger

/**
 * P1: the headless approval gateway.
 *
 * There is no window in `--turn` mode, so nobody can answer. The only honest
 * default is **deny**, and the counter makes that visible in tests and in the
 * turn envelope.
 *
 * This is not a policy switch. It cannot allow an action, and no flag turns it
 * into an allow-all gateway: an allow decision needs a person, which is what
 * `HostApproval` provides in the window.
 */
class DenyAllApproval : ApprovalGateway {
    private val asked = AtomicInteger(0)

    val requests: Int
        get() = asked.get()

    override suspend fun approve(request: ApprovalRequest): Boolean {
        asked.incrementAndGet()
        return false
    }
}
