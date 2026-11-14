package com.hopa.core.router

object AppRouter {
    private val GENERIC = setOf(
        "app", "apps", "web", "www", "site", "website", "browser", "phone",
        "open", "use", "应用", "网站", "网页", "浏览器", "打开", "使用",
    )

    fun route(goal: String, targets: List<RouteTarget>): RouteMatch {
        val text = goal.trim().lowercase()
        var best = RouteMatch(target = null, score = -1, term = "")
        if (text.isEmpty()) {
            return best
        }
        for (target in targets) {
            val scored = score(target, text)
            if (scored.score <= 0) {
                continue
            }
            val current = best.target
            if (
                current == null ||
                scored.score > best.score ||
                (scored.score == best.score && canOpen(target) && !canOpen(current))
            ) {
                best = scored
            }
        }
        return best
    }

    private fun score(target: RouteTarget, text: String): RouteMatch {
        var best = -1
        var term = ""
        val terms = listOf(target.display, target.name) + target.aliases
        for (raw in terms) {
            val value = raw.trim().lowercase()
            if (value.length < 2 || value in GENERIC) {
                continue
            }
            if (value.all { it.isDigit() } && value.length < 3) {
                continue
            }
            if (containsTerm(text, value) && value.length > best) {
                best = value.length
                term = value
            }
        }
        for (domain in target.domains) {
            val value = normaliseHost(domain)
            if (value.length >= 3 && text.contains(value) && value.length > best) {
                best = value.length
                term = value
            }
        }
        val bundle = target.bundle.lowercase()
        if (bundle.length >= 3 && text.contains(bundle) && bundle.length > best) {
            best = bundle.length
            term = bundle
        }
        return RouteMatch(target = if (best < 0) null else target, score = best, term = term)
    }

    private fun containsTerm(text: String, term: String): Boolean {
        var from = 0
        while (true) {
            val index = text.indexOf(term, from)
            if (index < 0) {
                return false
            }
            val before = if (index > 0) text[index - 1] else null
            val after = if (index + term.length < text.length) text[index + term.length] else null
            val leftOk = !isAsciiAlnum(term.first()) || before == null || !isAsciiAlnum(before)
            val rightOk = !isAsciiAlnum(term.last()) || after == null || !isAsciiAlnum(after)
            if (leftOk && rightOk) {
                return true
            }
            from = index + 1
        }
    }

    private fun isAsciiAlnum(value: Char): Boolean =
        value in 'a'..'z' || value in '0'..'9'

    private fun normaliseHost(value: String): String =
        value.trim().lowercase().removePrefix("www.")

    private fun canOpen(target: RouteTarget): Boolean =
        target.bundle.isNotEmpty() || target.domains.isNotEmpty()
}
