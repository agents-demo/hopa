package com.hopa.sidecar.device

import com.hopa.contracts.wire.Action
import com.hopa.agent.action.PathSelector
import com.hopa.agent.action.PathTier
import com.hopa.agent.action.PlannedAction

/**
 * The Windows path selector.
 *
 * A settings launch becomes a URI (`intent`) instead of a sequence of clicks; a
 * system or app function is `api`; anything that needs the UI tree is `uia`; and
 * a gesture with no ref is `input` because only coordinates are left.
 *
 * The rewrite happens before the gate, so approval and the record describe the
 * action that actually runs.
 *
 * A launch that has a URI also keeps the plain UIA launch as a second candidate.
 * If there is no host to open the URI (headless, or a build without a system
 * port), the executor falls through to that launch and logs the tier it left.
 */
class WindowsPathSelector(
    private val intents: WindowsIntents = WindowsIntents(),
) : PathSelector {
    override fun choose(action: Action): PlannedAction = plan(action).first()

    override fun plan(action: Action): List<PlannedAction> = when {
        action.kind == "system.openLink" -> listOf(PlannedAction(action, PathTier.INTENT))
        action.kind == "ui.launch" -> launch(action)
        action.kind == "app.function" -> listOf(PlannedAction(action, PathTier.API))
        action.kind.startsWith("system.") -> listOf(PlannedAction(action, PathTier.API))
        action.kind.startsWith("web.") -> listOf(PlannedAction(action, PathTier.API))
        action.kind in setOf("ui.back", "ui.home") -> listOf(PlannedAction(action, PathTier.INPUT))
        action.kind in setOf("ui.tap", "ui.doubleTap", "ui.longPress", "ui.swipe", "ui.scroll") ->
            listOf(
                PlannedAction(
                    action,
                    if (action.ref.isNullOrBlank()) PathTier.INPUT else PathTier.UIA,
                ),
            )
        action.kind == "ui.type" ->
            listOf(PlannedAction(action, if (action.ref.isNullOrBlank()) PathTier.INPUT else PathTier.UIA))
        action.kind.startsWith("ui.") -> listOf(PlannedAction(action, PathTier.UIA))
        else -> listOf(PlannedAction(action, PathTier.UIA))
    }

    private fun launch(action: Action): List<PlannedAction> {
        val target = action.app?.takeIf { it.isNotBlank() } ?: action.text.orEmpty()
        val uri = intents.resolve(target)
        val uia = PlannedAction(action, PathTier.UIA)
        return if (uri == null) {
            listOf(uia)
        } else {
            listOf(
                PlannedAction(
                    action.copy(kind = "system.openLink", url = uri, app = null),
                    PathTier.INTENT,
                ),
                uia,
            )
        }
    }
}
