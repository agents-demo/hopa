package hopa.brain.knowledge
import hopa.brain.routing.KnowledgeEntry


import java.nio.file.Files
import java.nio.file.Path

data class SiteManifest(
    val name: String,
    val display: String,
    val domains: List<String>,
    val aliases: List<String> = emptyList(),
    val apps: List<String> = emptyList(),
    val validated: String = "pending",
    val platform: String = "harmonyos",
) {
    fun toEntry(): KnowledgeEntry = KnowledgeEntry(
        name = name,
        display = display,
        aliases = aliases,
        domains = domains,
        service = name,
    )
}

class SiteFormatException(message: String) : IllegalArgumentException(message)

/** Loads `SITE.md` manifests with a strict, dependency-free front matter. */
object SiteLoader {
    fun load(directory: Path): List<SiteManifest> {
        val sites = mutableListOf<SiteManifest>()
        Files.walk(directory).use { stream ->
            stream
                .filter { it.fileName.toString() == "SITE.md" }
                .forEach { path ->
                    sites.add(parse(Files.readString(path), path.toString()))
                }
        }
        return sites.sortedBy { it.name }
    }

    fun parse(text: String, source: String = "<memory>"): SiteManifest {
        val normalised = text.replace("\r\n", "\n")
        if (!normalised.startsWith("---\n")) {
            throw SiteFormatException("$source: missing front matter")
        }
        val end = normalised.indexOf("\n---", 4)
        if (end < 0) {
            throw SiteFormatException("$source: front matter is not closed")
        }

        val fields = mutableMapOf<String, String>()
        for (line in normalised.substring(4, end).split("\n")) {
            val trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) continue
            val colon = trimmed.indexOf(':')
            if (colon <= 0) {
                throw SiteFormatException("$source: invalid line: $trimmed")
            }
            fields[trimmed.substring(0, colon).trim()] =
                trimmed.substring(colon + 1).trim()
        }

        fun required(key: String): String =
            fields[key] ?: throw SiteFormatException("$source: missing $key")

        val domains = parseList(fields["domains"])
        if (domains.isEmpty()) {
            throw SiteFormatException("$source: domains must not be empty")
        }
        val platform = required("platform")
        if (platform != "harmonyos") {
            throw SiteFormatException("$source: platform must be harmonyos, got $platform")
        }

        return SiteManifest(
            name = required("name"),
            display = required("display"),
            domains = domains,
            aliases = parseList(fields["aliases"]),
            apps = parseList(fields["apps"]),
            validated = fields["validated"] ?: "pending",
            platform = platform,
        )
    }

    private fun parseList(raw: String?): List<String> {
        if (raw == null || raw.isEmpty()) return emptyList()
        val inner = raw.removePrefix("[").removeSuffix("]")
        return inner
            .split(",")
            .map { it.trim().removeSurrounding("\"") }
            .filter { it.isNotEmpty() }
    }
}
