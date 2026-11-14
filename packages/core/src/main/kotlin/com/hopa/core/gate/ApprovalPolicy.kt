package com.hopa.core.gate

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.RiskLevel
import com.hopa.policy.ApprovalPolicyData

class ApprovalPolicy(
    private val classifier: ActionClassifier = ActionClassifier(),
) {
    private var autonomous: Boolean = false
    private val trustedApps = mutableSetOf<String>()

    fun setAutonomous(value: Boolean) {
        autonomous = value
    }

    fun isAutonomous(): Boolean = autonomous

    fun setTrustedApps(apps: List<String>) {
        trustedApps.clear()
        apps.map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
            .forEach { trustedApps += it }
    }

    fun isTrustedApp(packageName: String): Boolean =
        trustedApps.contains(packageName.trim().lowercase())

    fun classify(action: Action, observation: Observation? = null): RiskLevel {
        val app = action.app?.trim()?.lowercase().orEmpty()
        if (
            action.kind in ApprovalPolicyData.TRUSTED_APP_KINDS &&
            app.isNotEmpty() &&
            trustedApps.contains(app)
        ) {
            return RiskLevel.READ
        }
        return classifier.classify(action, observation)
    }

    fun isPayment(action: Action, observation: Observation? = null): Boolean =
        classify(action, observation) == RiskLevel.PAYMENT

    fun requiresApproval(action: Action, observation: Observation? = null): Boolean {
        if (isPayment(action, observation)) {
            return true
        }
        if (autonomous) {
            return false
        }
        return classify(action, observation) != RiskLevel.READ
    }

    fun request(action: Action, observation: Observation? = null): ApprovalRequest {
        val payment = classifier.extractPaymentContext(observation)
        val isPayment = isPayment(action, observation)
        val title = if (isPayment) "Confirm payment" else "Allow this action?"
        val body = if (isPayment) {
            "Money may leave your account. HOPA cannot undo a payment."
        } else {
            "HOPA wants to ${action.kind.replace('.', ' ')} on this phone."
        }
        return ApprovalRequest(
            title = title,
            body = body,
            amount = payment.amount,
            merchant = payment.merchant,
            consequence = payment.consequence,
            isPayment = isPayment,
            action = action,
        )
    }

    fun extractPaymentContext(observation: Observation?): PaymentContext =
        classifier.extractPaymentContext(observation)
}
