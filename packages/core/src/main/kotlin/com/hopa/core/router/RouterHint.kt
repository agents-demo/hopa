package com.hopa.core.router

object RouterHint {
    fun text(match: RouteMatch): String {
        val target = match.target ?: return ""
        if (target.kind == "site") {
            val domain = target.domains.firstOrNull() ?: return ""
            return "ROUTER SUGGESTION: this is a ${target.display} task. " +
                "Open https://$domain with {\"kind\":\"web.navigate\",\"url\":\"https://$domain\"}, " +
                "then read the page and use its element refs."
        }
        if (target.bundle.isEmpty()) {
            return "ROUTER SUGGESTION: this looks like a ${target.display} task, " +
                "but no Android package is verified for it. Do not guess a package; " +
                "say what is missing and offer the web channel if one exists."
        }
        return "ROUTER SUGGESTION: this is a ${target.display} task. " +
            "Start with {\"kind\":\"ui.launch\",\"app\":\"${target.bundle}\"}, " +
            "then act on the ELEMENTS of the new screen."
    }
}
