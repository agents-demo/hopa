package com.hopa.core.narration

import com.hopa.core.contracts.Action

object RunNarrator {
    fun line(action: Action, executed: Boolean): String {
        val verb = when (action.kind) {
            "ui.launch" -> "Open ${action.app.orEmpty()}"
            "ui.tap" -> "Tap ${action.ref ?: "the screen"}"
            "ui.type" -> "Type into ${action.ref ?: "the field"}"
            "ui.swipe", "ui.scroll" -> "Scroll the screen"
            "web.navigate" -> "Open ${action.url.orEmpty()}"
            "web.read" -> "Read the page"
            else -> action.kind
        }
        return if (executed) verb else "$verb (not run)"
    }
}
