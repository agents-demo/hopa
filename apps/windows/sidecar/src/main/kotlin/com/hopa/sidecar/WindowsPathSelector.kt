package com.hopa.sidecar

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
 */
class WindowsPathSelector(
    private val intents: WindowsIntents = WindowsIntents(),
) : PathSelector {
    override fun choose(action: Action): PlannedAction = when {
        action.kind == "system.openLink" -> PlannedAction(action, PathTier.INTENT)
        action.kind == "ui.launch" -> launch(action)
        action.kind == "app.function" -> PlannedAction(action, PathTier.API)
        action.kind.startsWith("system.") -> PlannedAction(action, PathTier.API)
        action.kind.startsWith("web.") -> PlannedAction(action, PathTier.API)
        action.kind in setOf("ui.back", "ui.home") -> PlannedAction(action, PathTier.INPUT)
        action.kind in setOf("ui.tap", "ui.doubleTap", "ui.longPress", "ui.swipe", "ui.scroll") ->
            PlannedAction(
                action,
                if (action.ref.isNullOrBlank()) PathTier.INPUT else PathTier.UIA,
            )
        action.kind == "ui.type" ->
            PlannedAction(action, if (action.ref.isNullOrBlank()) PathTier.INPUT else PathTier.UIA)
        action.kind.startsWith("ui.") -> PlannedAction(action, PathTier.UIA)
        else -> PlannedAction(action, PathTier.UIA)
    }

    private fun launch(action: Action): PlannedAction {
        val target = action.app?.takeIf { it.isNotBlank() } ?: action.text.orEmpty()
        val uri = intents.resolve(target)
        return if (uri == null) {
            PlannedAction(action, PathTier.UIA)
        } else {
            PlannedAction(
                action.copy(kind = "system.openLink", url = uri, app = null),
                PathTier.INTENT,
            )
        }
    }
}
