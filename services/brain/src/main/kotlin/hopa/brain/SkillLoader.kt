package hopa.brain

import java.nio.file.Files
import java.nio.file.Path

data class SkillManifest(
    val name: String,
    val display: String,
    val description: String,
    val terms: List<String> = emptyList(),
    val apps: List<String> = emptyList(),
    val sites: List<String> = emptyList(),
)

class SkillFormatException(message: String) : IllegalArgumentException(message)

/** Loads `SKILL.md` manifests with a strict, dependency-free front matter. */
object SkillLoader {
    fun load(directory: Path): List<SkillManifest> {
        val skills = mutableListOf<SkillManifest>()
        Files.walk(directory).use { stream ->
            stream
                .filter { it.fileName.toString() == "SKILL.md" }
                .forEach { path ->
                    skills.add(parse(Files.readString(path), path.toString()))
                }
        }
        return skills.sortedBy { it.name }
    }

    fun parse(text: String, source: String = "<memory>"): SkillManifest {
        val normalised = text.replace("\r\n", "\n")
        if (!normalised.startsWith("---\n")) {
            throw SkillFormatException("$source: missing front matter")
        }
        val end = normalised.indexOf("\n---", 4)
        if (end < 0) {
            throw SkillFormatException("$source: front matter is not closed")
        }

        val fields = mutableMapOf<String, String>()
        for (line in normalised.substring(4, end).split("\n")) {
            val trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) continue
            val colon = trimmed.indexOf(':')
            if (colon <= 0) {
                throw SkillFormatException("$source: invalid line: $trimmed")
            }
            fields[trimmed.substring(0, colon).trim()] =
                trimmed.substring(colon + 1).trim()
        }

        fun required(key: String): String =
            fields[key] ?: throw SkillFormatException("$source: missing $key")

        return SkillManifest(
            name = required("name"),
            display = required("display"),
            description = required("description"),
            terms = parseList(fields["terms"]),
            apps = parseList(fields["apps"]),
            sites = parseList(fields["sites"]),
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
