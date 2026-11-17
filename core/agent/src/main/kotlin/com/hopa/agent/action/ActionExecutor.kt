package com.hopa.agent.action

import com.hopa.agent.classify.ActionKindRules
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.approval.RiskLevel
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.json.ObservationHasher
import com.hopa.contracts.ports.BrowserPort
import com.hopa.contracts.ports.Clock
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.ports.SandboxPort
import com.hopa.contracts.ports.SystemPort
import com.hopa.contracts.turn.ExecutionResult
import com.hopa.contracts.wire.Action
import com.hopa.contracts.wire.Observation
import com.hopa.observation.tree.NodeAnchor
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.runlog.store.RunRecorder

class ActionExecutor(
    private val device: DevicePort,
    private val browser: BrowserPort?,
    private val system: SystemPort?,
    private val sandbox: SandboxPort?,
    /**
     * The gate settings to use for this step. A supplier, because a setting can
     * change between steps while a run is in flight, and because one executor
     * serves the main turn and the parallel runs; each step reads one immutable
     * snapshot instead of sharing a mutable list.
     */
    private val policy: () -> ApprovalPolicy,
    private val approval: ApprovalGateway,
    private val recorder: RunRecorder,
    private val factory: RunRecordFactory,
    private val clock: Clock,
    private val scrollGeometry: ScrollGeometry = ScrollGeometry(),
    private val selector: PathSelector? = null,
    /** Called for each tier left behind, so the host can show the fallback. */
    private val onFallback: (String) -> Unit = {},
) {
    suspend fun execute(
        runId: String,
        step: Int,
        traceId: String,
        action: Action,
        before: Observation,
    ): ExecutionResult {
        val gate = policy()
        // The selector may replace a UI launch with a URI (intent) and may offer
        // further tiers. Everything below uses the chosen action, so the approval
        // and the record describe what actually runs.
        val attempts = selector?.plan(action)
            ?.takeIf { it.isNotEmpty() }
            ?.map { Attempt(it.action, it.tier.wire) }
            ?: listOf(Attempt(action, ""))
        val intended = attempts.first()
        // What the ref points at, kept so a recipe can find the same control
        // after the tree has been redrawn.
        val targetKey = intended.action.ref?.takeIf { it.isNotBlank() }
            ?.let { ref -> NodeAnchor.find(before.tree, ref)?.let(NodeAnchor::key) }
        val classification = gate.classify(intended.action, before)
        val needsApproval = gate.requiresApproval(intended.action, before)
        // One question for the whole action, asked before any tier runs. A
        // fallback retries a path, never the person's decision.
        val approved = if (needsApproval) {
            approval.approve(gate.request(intended.action, before))
        } else {
            null
        }
        val beforeHash = ObservationHasher.hashOf(before)

        if (needsApproval && approved != true) {
            val record = factory.draft(
                runId = runId,
                step = step,
                traceId = traceId,
                action = intended.action,
                classification = label(classification),
                tier = intended.tier,
                approved = false,
                observation = before,
                beforeHash = beforeHash,
                afterHash = beforeHash,
                verified = false,
                executed = false,
                targetKey = targetKey,
                error = ErrorCodes.REFUSED,
            ).let { recorder.append(it) }
            return ExecutionResult(record, before, "I did not run that.")
        }

        var index = 0
        while (index < attempts.size) {
            val attempt = attempts[index]
            val outcome = runCatching {
                val text = executeAction(attempt.action, before)
                val after = runCatching { device.observe() }.getOrDefault(before)
                val afterHash = ObservationHasher.hashOf(after)
                val changed = afterHash != beforeHash
                val verified = text.isNotEmpty() || attempt.action.kind in setOf(
                    "ui.observe", "ui.wait", "ui.back", "ui.home", "ui.stop",
                ) || changed
                val record = factory.draft(
                    runId = runId,
                    step = step,
                    traceId = traceId,
                    action = attempt.action,
                    classification = label(classification),
                    tier = attempt.tier,
                    approved = approved,
                    observation = after,
                    beforeHash = beforeHash,
                    afterHash = afterHash,
                    verified = verified,
                    executed = true,
                    targetKey = targetKey,
                ).let { recorder.append(it) }
                ExecutionResult(record, after, text)
            }
            val success = outcome.getOrNull()
            if (success != null) {
                return success
            }

            val error = outcome.exceptionOrNull()!!
            val next = attempts.getOrNull(index + 1)
            if (error is UnsupportedOperationException && next != null) {
                // An unavailable tier is not a device failure. Leave it visibly
                // and try the next tier; never fall through silently.
                onFallback(
                    "tier ${attempt.tier} unavailable (${ErrorCodes.UNSUPPORTED}); " +
                        "falling back to ${next.tier}",
                )
                index++
                continue
            }

            // Either the last tier is unavailable, or the device actually broke.
            // A device error is never retried: only unavailable tiers fall through.
            val code = if (error is UnsupportedOperationException) {
                ErrorCodes.UNSUPPORTED
            } else {
                ErrorCodes.DEVICE
            }
            val record = factory.draft(
                runId = runId,
                step = step,
                traceId = traceId,
                action = attempt.action,
                classification = label(classification),
                tier = attempt.tier,
                approved = approved,
                observation = before,
                beforeHash = beforeHash,
                afterHash = beforeHash,
                verified = false,
                executed = false,
                targetKey = targetKey,
                error = code,
            ).let { recorder.append(it) }
            return ExecutionResult(record, before, "I could not do that: ${error.message ?: code}")
        }
        throw IllegalStateException("no path was attempted")
    }

    /** One candidate path: the action to run and the wire name of its tier. */
    private data class Attempt(val action: Action, val tier: String)

    private suspend fun executeAction(action: Action, before: Observation): String {
        // The same table the parser uses: an incomplete step is a mistake, not a
        // gesture at a guess.
        action.kindOrNull()?.let { kind ->
            ActionKindRules.missing(kind, action)?.let { throw IllegalArgumentException(it) }
        }
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

            "ui.scroll" -> {
                val points = if (action.x != null && action.y != null) {
                    val x = action.x!!
                    val y = action.y!!
                    intArrayOf(x, y, action.toX ?: x, action.toY ?: y)
                } else {
                    scrollGeometry.swipe(before.screenSize, action.direction.orEmpty())
                }
                device.swipe(points[0], points[1], points[2], points[3])
            }

            "ui.back" -> device.pressBack()
            "ui.home" -> device.pressHome()
            "ui.launch" -> {
                device.launch(action.app.orEmpty())
                return ""
            }

            "app.function" -> {
                return device.appFunction(
                    action.app.orEmpty(),
                    action.ref.orEmpty(),
                    action.text.orEmpty().ifBlank { "{}" },
                )
            }

            "ui.stop" -> device.stop(action.app.orEmpty())

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
                port.click(action.ref.orEmpty())
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

            "system.setAlarm" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                val clockTime = parseClock(action.text.orEmpty())
                port.setAlarm(clockTime[0], clockTime[1], "")
            }

            "system.uninstall" -> {
                val port = system ?: throw UnsupportedOperationException("no system port")
                port.uninstall(action.app ?: action.text.orEmpty())
            }

            "sandbox.run" -> {
                val port = sandbox ?: throw UnsupportedOperationException("no sandbox")
                return port.run(action.text.orEmpty())
            }

            // A payment is still a device gesture: the tap or the card entry the
            // person approved. Without this, an approved payment could never run.
            "payment.pay", "payment.confirm", "payment.checkout", "payment.authorize" ->
                device.tap(action.ref, action.x, action.y)

            "payment.enterCard" -> device.type(action.text.orEmpty(), action.ref)

            else -> throw UnsupportedOperationException("unsupported kind: ${action.kind}")
        }
        return ""
    }

    /** "07:30" or "7:30" to hour and minute; noon when the text makes no sense. */
    private fun parseClock(text: String): IntArray {
        val match = Regex("(\\d{1,2}):(\\d{2})").find(text) ?: return intArrayOf(12, 0)
        return intArrayOf(
            match.groupValues[1].toInt().coerceIn(0, 23),
            match.groupValues[2].toInt().coerceIn(0, 59),
        )
    }

    private fun label(level: RiskLevel): String = when (level) {
        RiskLevel.READ -> "read"
        RiskLevel.SENSITIVE -> "sensitive"
        RiskLevel.PAYMENT -> "payment"
    }
}
