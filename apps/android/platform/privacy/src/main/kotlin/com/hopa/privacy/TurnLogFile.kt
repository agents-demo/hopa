package com.hopa.privacy

import android.content.Context
import java.io.File

/**
 * A small file of pipe-separated lines, so "what left your phone" survives a
 * restart. No screen text, no identifiers - only sizes and the goal.
 */
class TurnLogFile(context: Context) {
    private val file = File(context.filesDir, "turn-log.txt")

    fun load(): List<TurnLogEntry> {
        if (!file.exists()) {
            return emptyList()
        }
        return runCatching {
            file.readLines()
                .mapNotNull { line ->
                    val parts = line.split('|')
                    if (parts.size < 6) {
                        return@mapNotNull null
                    }
                    TurnLogEntry(
                        at = parts[0].toLongOrNull() ?: 0L,
                        path = parts[1],
                        steps = parts[2].toIntOrNull() ?: 0,
                        tokens = parts[3].toIntOrNull() ?: 0,
                        charactersSent = parts[4].toIntOrNull() ?: 0,
                        goal = parts.drop(5).joinToString("|").replace('\n', ' '),
                    )
                }
                .takeLast(50)
        }.getOrDefault(emptyList())
    }

    fun append(entry: TurnLogEntry) {
        runCatching {
            val line = listOf(
                entry.at.toString(),
                entry.path,
                entry.steps.toString(),
                entry.tokens.toString(),
                entry.charactersSent.toString(),
                entry.goal.replace('|', '/').replace('\n', ' '),
            ).joinToString("|")
            file.appendText(line + "\n")
            val lines = file.readLines()
            if (lines.size > 50) {
                file.writeText(lines.takeLast(50).joinToString("\n") + "\n")
            }
        }
    }
}
