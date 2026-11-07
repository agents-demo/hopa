package hopa.brain.knowledge
import hopa.brain.routing.KnowledgeEntry


import java.nio.file.Files
import java.nio.file.Path

/**
 * Loads HarmonyOS app knowledge from Markdown files with a small, strict
 * front-matter block. No YAML library is required.
 *
 * Format:
 * ```
 * ---
 * name: settings
 * display: Settings
 * bundle: com.huawei.hmos.settings
 * aliases: [设置, settings]
 * pace: careful
 * validated: pending
 * platform: harmonyos
 * ---
 * ```
 */
data class KnowledgeDocument(
    val entry: KnowledgeEntry,
    val body: String,
    val pace: String,
    val validated: String,
    val platform: String,
)

class KnowledgeFormatException(message: String) : IllegalArgumentException(message)

object KnowledgeLoader {
    fun load(directory: Path): List<KnowledgeDocument> {
        val documents = mutableListOf<KnowledgeDocument>()
        Files.walk(directory).use { stream ->
            stream
                .filter { it.fileName.toString() == "APP.md" }
                .forEach { path ->
                    documents.add(parse(Files.readString(path), path.toString()))
                }
        }
        return documents.sortedBy { it.entry.name }
    }

    fun parse(text: String, source: String = "<memory>"): KnowledgeDocument {
        val normalised = text.replace("\r\n", "\n")
        if (!normalised.startsWith("---\n")) {
            throw KnowledgeFormatException("$source: missing front matter")
        }
        val end = normalised.indexOf("\n---", 4)
        if (end < 0) {
            throw KnowledgeFormatException("$source: front matter is not closed")
        }

        val front = normalised.substring(4, end)
        val body = normalised.substring(end + 4).trimStart('\n')
        val fields = mutableMapOf<String, String>()

        for (line in front.split("\n")) {
            val trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) continue
            val colon = trimmed.indexOf(':')
            if (colon <= 0) {
                throw KnowledgeFormatException("$source: invalid line: $trimmed")
            }
            fields[trimmed.substring(0, colon).trim()] =
                trimmed.substring(colon + 1).trim()
        }

        fun required(key: String): String =
            fields[key] ?: throw KnowledgeFormatException("$source: missing $key")

        val platform = required("platform")
        if (platform != "harmonyos") {
            throw KnowledgeFormatException("$source: platform must be harmonyos, got $platform")
        }

        val bundle = required("bundle")
        // UNCONFIRMED means the app is catalogued but no HarmonyOS bundle has
        // been verified on a device. It must never be used to launch anything.
        val packages = if (bundle.equals("UNCONFIRMED", ignoreCase = true) ||
            bundle.equals("unknown", ignoreCase = true)
        ) {
            emptyList()
        } else {
            listOf(bundle)
        }
        val entry = KnowledgeEntry(
            name = required("name"),
            display = required("display"),
            aliases = parseList(fields["aliases"]),
            packages = packages,
            service = fields["service"] ?: required("name"),
        )
        return KnowledgeDocument(
            entry = entry,
            body = body,
            pace = required("pace"),
            validated = required("validated"),
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
