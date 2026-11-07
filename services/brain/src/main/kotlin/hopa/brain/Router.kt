package hopa.brain

/**
 * Pure-Kotlin routing reference for the HOPA brain.
 *
 * This is a clean-room implementation of the lexical rules described in
 * docs/adr/0002 and docs/port-log.md. It has no Android imports and no
 * dependency on the UI.
 */

data class KnowledgeEntry(
    val name: String,
    val display: String,
    val aliases: List<String> = emptyList(),
    val packages: List<String> = emptyList(),
    val domains: List<String> = emptyList(),
    val service: String = name,
    val packageAliases: Map<String, String> = emptyMap(),
)

data class ChannelFacts(
    val installed: Set<String> = emptySet(),
    val loggedInSites: Set<String> = emptySet(),
    val webAvailable: Boolean = false,
)

class KnowledgeStore(private val entries: List<KnowledgeEntry>) {

    fun byPackage(pkg: String): KnowledgeEntry? =
        entries.firstOrNull { pkg in it.packages }

    fun byDomain(host: String): KnowledgeEntry? {
        val h = normaliseHost(host)
        return entries.firstOrNull { entry ->
            entry.domains.any { domain ->
                val d = normaliseHost(domain)
                h == d || h.endsWith(".$d")
            }
        }
    }

    /**
     * Lexical match: display name, name, aliases, packages and domains.
     * Installed apps sort first; ties break on the longest matched term.
     */
    fun matchTask(
        text: String,
        limit: Int = 2,
        installed: List<Pair<String, String>> = emptyList(),
    ): List<KnowledgeEntry> {
        val haystack = text.lowercase()
        val installedPackages = installed.map { it.first }.toSet()
        val followers = installed
            .map { it.second.trim().lowercase() }
            .filter { it.length >= 2 }
            .distinct()

        return entries
            .mapNotNull { entry -> score(entry, haystack, followers)?.let { entry to it } }
            .sortedWith(
                compareBy(
                    { it.first.packages.none(installedPackages::contains) },
                    { -it.second },
                    { it.first.name },
                ),
            )
            .map { it.first }
            .distinctBy { it.service }
            .take(limit)
    }

    fun packageFor(nameOrAlias: String): String? {
        val query = nameOrAlias.trim().lowercase()
        if (query.isEmpty()) return null
        val candidates = entries
            .filter { it.packages.isNotEmpty() }
            .filter { entry ->
                (listOf(entry.name, entry.display) + entry.aliases)
                    .any { it.lowercase() == query }
            }
        val chosen = candidates.firstOrNull() ?: return null
        return chosen.packageAliases.entries
            .firstOrNull { it.key.lowercase() == query }?.value
            ?: chosen.packages.first()
    }

    private fun score(entry: KnowledgeEntry, text: String, followers: List<String>): Int? {
        var best = -1
        val terms = (listOf(entry.display, entry.name) + entry.aliases)
            .map { it.trim().lowercase() }
        val others = followers.filter { follower -> terms.none { it.endsWith(follower) } }

        for (term in terms) {
            if (term.length < 2 || term in GENERIC) continue
            if (term.all { it.isDigit() } && term.length < 3) continue
            if (containsTerm(text, term, others)) best = maxOf(best, term.length)
        }
        for (domain in entry.domains) {
            val value = normaliseHost(domain)
            if (value.length >= 3 && text.contains(value)) best = maxOf(best, value.length)
        }
        for (pkg in entry.packages) {
            val value = pkg.lowercase()
            if (value.length >= 3 && text.contains(value)) best = maxOf(best, value.length)
        }
        return best.takeIf { it >= 0 }
    }

    private fun containsTerm(
        text: String,
        term: String,
        others: List<String> = emptyList(),
    ): Boolean {
        var from = 0
        while (true) {
            val index = text.indexOf(term, from)
            if (index < 0) return false
            val before = text.getOrNull(index - 1)
            val after = text.getOrNull(index + term.length)
            val leftOk = !term.first().isAsciiAlnum() || before == null || !before.isAsciiAlnum()
            val rightOk = !term.last().isAsciiAlnum() || after == null || !after.isAsciiAlnum()
            val namesAnother = others.any { text.startsWith(it, index + term.length) }
            if (leftOk && rightOk && !namesAnother) return true
            from = index + 1
        }
    }

    private fun Char.isAsciiAlnum(): Boolean =
        this in 'a'..'z' || this in '0'..'9'

    private fun normaliseHost(value: String): String =
        value.trim().lowercase().removePrefix("www.")

    companion object {
        private val GENERIC = setOf(
            "app", "apps", "web", "www", "site", "website", "browser", "phone", "open",
            "应用", "网站", "网页", "浏览器", "打开", "使用",
        )
    }
}

object ChannelAdvisor {
    private const val MAX_CHANNELS = 3

    fun line(entries: List<KnowledgeEntry>, facts: ChannelFacts): String? {
        val parts = entries
            .groupBy { it.service }
            .values
            .mapNotNull { channel(it, facts) }
            .take(MAX_CHANNELS)
        if (parts.isEmpty()) return null
        return "Available channels: " + parts.joinToString(" | ")
    }

    private fun channel(same: List<KnowledgeEntry>, facts: ChannelFacts): String? {
        val first = same.first()
        val packages = same.flatMap { it.packages }.distinct()
        val domains = same
            .flatMap { it.domains }
            .map { it.trim().lowercase().removePrefix("www.") }
            .filter { it.isNotEmpty() }
            .distinct()

        val app = if (packages.isEmpty()) {
            null
        } else {
            val installed = packages.firstOrNull { it in facts.installed }
            if (installed != null) "app: installed ($installed)" else "app: not installed"
        }

        val web = domains.firstOrNull()?.takeIf { facts.webAvailable }?.let { domain ->
            val signedIn = facts.loggedInSites.any { site ->
                val value = site.trim().lowercase().removePrefix("www.")
                value == domain || value.endsWith(".$domain")
            }
            if (signedIn) "web: $domain, signed in" else "web: $domain"
        }

        if (app == null && web == null) return null
        return "${first.display} - " + listOfNotNull(app, web).joinToString("; ")
    }
}
