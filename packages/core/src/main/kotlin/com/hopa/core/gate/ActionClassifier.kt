package com.hopa.core.gate

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.RiskLevel
import com.hopa.policy.ApprovalPolicyData

class ActionClassifier {
    fun classify(action: Action, observation: Observation?): RiskLevel {
        if (action.kind in ApprovalPolicyData.PAYMENT_KINDS) {
            return RiskLevel.PAYMENT
        }
        if (isPaymentScreen(observation) && action.kind in ApprovalPolicyData.INTERACTIVE_KINDS) {
            return RiskLevel.PAYMENT
        }
        if (action.kind in ApprovalPolicyData.SENSITIVE_KINDS) {
            return RiskLevel.SENSITIVE
        }
        if (action.kind in ApprovalPolicyData.ALLOWED_KINDS) {
            return RiskLevel.READ
        }
        return RiskLevel.SENSITIVE
    }

    fun isPaymentScreen(observation: Observation?): Boolean {
        val text = textOf(observation) ?: return false
        if (hasPaymentAction(text)) {
            return true
        }
        return hasAmount(text) && containsAny(text, ApprovalPolicyData.PAYMENT_WORDS)
    }

    fun extractPaymentContext(observation: Observation?): PaymentContext {
        val text = textOf(observation) ?: return PaymentContext(
            consequence = ApprovalPolicyData.PAYMENT_CONSEQUENCE,
        )
        var amount = ""
        var currency = ""
        var merchant = ""
        for (line in text.lines()) {
            val trimmed = line.trim()
            if (trimmed.isEmpty()) {
                continue
            }
            if (amount.isEmpty()) {
                val match = ApprovalPolicyData.CURRENCY_RE.find(trimmed)
                if (match != null) {
                    amount = match.value.trim()
                    val token = ApprovalPolicyData.CURRENCY_TOKEN_RE.find(amount)
                    if (token != null) {
                        currency = token.value
                    }
                }
            }
            if (merchant.isEmpty()) {
                val lower = trimmed.lowercase()
                if (ApprovalPolicyData.MERCHANT_PREFIXES.any { lower.startsWith(it) }) {
                    val index = trimmed.indexOf(':')
                    merchant = if (index >= 0) trimmed.substring(index + 1).trim() else trimmed
                }
            }
        }
        return PaymentContext(
            amount = amount,
            currency = currency,
            merchant = merchant,
            consequence = ApprovalPolicyData.PAYMENT_CONSEQUENCE,
        )
    }

    private fun textOf(observation: Observation?): String? {
        if (observation == null) {
            return null
        }
        if (observation.text.isNotEmpty()) {
            return observation.text
        }
        val lines = mutableListOf<String>()
        fun walk(node: com.hopa.core.contracts.ObservationNode) {
            if (node.text.isNotEmpty()) {
                lines += node.text
            }
            if (node.description.isNotEmpty()) {
                lines += node.description
            }
            node.children.forEach(::walk)
        }
        walk(observation.tree)
        return lines.joinToString("\n")
    }

    private fun hasPaymentAction(text: String): Boolean {
        for (line in text.lines()) {
            val trimmed = line.trim().lowercase()
            if (trimmed.isEmpty() || trimmed.length > 24) {
                continue
            }
            if (trimmed in ApprovalPolicyData.PAYMENT_ACTIONS) {
                return true
            }
        }
        return false
    }

    private fun hasAmount(text: String): Boolean =
        ApprovalPolicyData.CURRENCY_RE.containsMatchIn(text) ||
            ApprovalPolicyData.TOTAL_RE.containsMatchIn(text)

    private fun containsAny(text: String, words: List<String>): Boolean {
        val lower = text.lowercase()
        return words.any { lower.contains(it.lowercase()) }
    }
}
