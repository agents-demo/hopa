package com.hopa.core.gate

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.ErrorCodes
import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.RiskLevel
import com.hopa.core.observation.ObservationHasher
import com.hopa.core.ports.BrowserPort
import com.hopa.core.ports.Clock
import com.hopa.core.ports.DevicePort
import com.hopa.core.ports.SandboxPort
import com.hopa.core.ports.SystemPort
import com.hopa.core.records.RunRecordFactory
import com.hopa.core.records.RunRecorder

class ActionExecutor(
    private val device: DevicePort,
    private val browser: BrowserPort?,
    private val system: SystemPort?,
    private val sandbox: SandboxPort?,
    private val policy: ApprovalPolicy,
    private val approval: ApprovalGateway,
    private val recorder: RunRecorder,
    private val factory: RunRecordFactory,
    private val clock: Clock,
) {
    suspend fun execute(
        runId: String,
        step: Int,
        traceId: String,
        action: Action,
        before: Observation,
    ): ExecutionResult {
        val classification = policy.classify(action, before)
        val needsApproval = policy.requiresApproval(action, before)
        val approved = if (needsApproval) {
            approval.approve(policy.request(action, before))
        } else {
            null
        }
        val beforeHash = ObservationHasher.hash(before)

        if (needsApproval && approved != true) {
            val record = factory.draft(
                runId = runId,
                step = step,
                traceId = traceId,
                action = action,
                classification = label(classification),
                approved = false,
                observation = before,
                beforeHash = beforeHash,
                afterHash = beforeHash,
                verified = false,
                executed = false,
                error = ErrorCodes.REFUSED,
            ).let { recorder.append(it) }
            return ExecutionResult(record, before, "I did not run that.")
        }

        return runCatching {
            val text = executeAction(action)
            val after = runCatching { device.observe() }.getOrDefault(before)
            val changed = ObservationHasher.hash(after) != beforeHash
            val verified = text.isNotEmpty() || action.kind in setOf(
                "ui.observe", "ui.wait", "ui.back", "ui.home", "ui.stop",
            ) || changed
            val record = factory.draft(
                runId = runId,
                step = step,
                traceId = traceId,
                action = action,
                classification = label(classification),
                approved = approved,
                observation = after,
                beforeHash = beforeHash,
                afterHash = ObservationHasher.hash(after),
                verified = verified,
                executed = true,
            ).let { recorder.append(it) }
            ExecutionResult(record, after, text)
        }.getOrElse { error ->
            val code = if (error is UnsupportedOperationException) {
                ErrorCodes.UNSUPPORTED
            } else {
                ErrorCodes.DEVICE
            }
            val record = factory.draft(
                runId = runId,
                step = step,
                traceId = traceId,
                action = action,
                classification = label(classification),
                approved = approved,
                observation = before,
                beforeHash = beforeHash,
                afterHash = beforeHash,
                verified = false,
                executed = false,
                error = code,
            ).let { recorder.append(it) }
            ExecutionResult(record, before, "I could not do that: ${error.message ?: code}")
        }
    }

    private suspend fun executeAction(action: Action): String {
        when (action.kind) {
            "ui.observe" -> return ""
            "ui.tap" -> device.tap(action.ref, action.x, action.y)
            "ui.doubleTap" -> device.doubleTap(action.ref, action.x, action.y)
            "ui.longPress" -> device.longPress(action.ref, action.x, action.y)

            "ui.type" -> device.type(action.text.orEmpty(), action.ref)
            "ui.swipe" -> device.swipe(
                action.x ?: 500,
                action.y ?: 1500,
                action.toX ?: 500,
                action.toY ?: 500,
            )

            "ui.scroll" -> device.swipe(
                action.x ?: 500,
                action.y ?: 1500,
                action.toX ?: 500,
                action.toY ?: 500,
            )

            "ui.back" -> device.pressBack()
            "ui.home" -> device.pressHome()
            "ui.launch" -> {
                val packageName = action.app?.takeIf { it.isNotBlank() }
                    ?: throw IllegalArgumentException("ui.launch needs app")
                device.launch(packageName)
                return ""
            }

            "ui.stop" -> device.stop(
                action.app?.takeIf { it.isNotBlank() }
                    ?: throw IllegalArgumentException("ui.stop needs app"),
            )

            "ui.wait" -> clock.sleep(action.timeoutMs.toLong())
            "web.navigate" -> {
                val port = browser ?: throw UnsupportedOperationException("no browser")
                return port.navigate(action.url ?: action.text.orEmpty())
            }

            "web.read" -> {
                val port = browser ?: throw UnsupportedOperationException("no browser")
                return port.read()
            }

            "web.click" -> {
                val port = browser ?: throw UnsupportedOperationException("no browser")
                port.click(action.ref ?: throw IllegalArgumentException("web.click needs ref"))
            }

            "web.type" -> {
                val port = browser ?: throw UnsupportedOperationException("no browser")
                port.type(action.text.orEmpty(), action.ref)
            }

            "system.openLink" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                port.openLink(action.url ?: action.text.orEmpty())
            }

            "system.share" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                port.share(action.text.orEmpty())
            }

            "system.sendMessage" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                port.sendMessage(action.app.orEmpty(), action.text.orEmpty())
            }

            "system.call" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                port.call(action.text.orEmpty())
            }

            "system.uninstall" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                port.uninstall(action.app ?: action.text.orEmpty())
            }

            "sandbox.run" -> {
                val port = sandbox ?: throw UnsupportedOperationException("no sandbox")
                return port.run(action.text.orEmpty())
            }

            else -> throw UnsupportedOperationException("unsupported kind: ${action.kind}")
        }
        return ""
    }

    private fun label(level: RiskLevel): String = when (level) {
        RiskLevel.READ -> "read"
        RiskLevel.SENSITIVE -> "sensitive"
        RiskLevel.PAYMENT -> "payment"
    }
}
