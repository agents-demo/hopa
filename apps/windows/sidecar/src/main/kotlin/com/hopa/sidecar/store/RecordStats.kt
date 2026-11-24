package com.hopa.sidecar.store

import java.time.Instant
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** One finished turn, flattened for the history screen. */
data class HistoryEntry(
    val conversationId: String,
    val title: String,
    val runId: String,
    val createdAt: Long,
    val steps: Int,
    val executed: Int,
    val failed: Int,
)

/** The usage counters Android builds from every recorded action. */
data class UsageStats(
    val total: Int,
    val executed: Int,
    val failed: Int,
    val payments: Int,
    val lastSevenDays: Int,
    val topActions: List<Pair<String, Int>>,
)

/**
 * The history/usage projection over the raw turn records. Pure and deterministic
 * so the screens and the tests read the same numbers.
 */
object RecordStats {
    private const val WEEK_MS = 7L * 24 * 60 * 60 * 1000

    fun history(turns: List<JsonObject>, titleOf: (String) -> String): List<HistoryEntry> =
        turns.map { turn ->
            val records = records(turn)
            HistoryEntry(
                conversationId = turn.text("conversationId"),
                title = titleOf(turn.text("conversationId")),
                runId = turn.text("runId"),
                createdAt = turn.long("createdAt"),
                steps = records.size,
                executed = records.count { it.executed() },
                failed = records.count { !it.executed() },
            )
        }

    fun usage(turns: List<JsonObject>, now: Long = System.currentTimeMillis()): UsageStats {
        val all = turns.flatMap(::records)
        val cutoff = now - WEEK_MS
        val top = all.groupingBy { it.kind() }.eachCount()
            .entries
            .sortedByDescending { it.value }
            .take(6)
            .map { it.key to it.value }
        val recent = turns.sumOf { turn ->
            val createdAt = turn.long("createdAt")
            records(turn).count { at(it, createdAt) >= cutoff }
        }

        return UsageStats(
            total = all.size,
            executed = all.count { it.executed() },
            failed = all.count { !it.executed() },
            payments = all.count { it.text("classification") == "payment" },
            lastSevenDays = recent,
            topActions = top,
        )
    }

    private fun records(turn: JsonObject): List<JsonObject> =
        (turn["records"] as? JsonArray)?.mapNotNull { it as? JsonObject }.orEmpty()

    private fun at(record: JsonObject, createdAt: Long): Long {
        val timestamp = record.text("timestamp")
        if (timestamp.isNotBlank()) {
            runCatching { Instant.parse(timestamp).toEpochMilli() }.getOrNull()?.let { return it }
        }
        // The turn time is the fallback when a record carries no timestamp.
        return createdAt
    }

    private fun JsonObject.executed(): Boolean =
        this["executed"]?.jsonPrimitive?.booleanOrNull == true

    private fun JsonObject.kind(): String =
        this["action"]?.jsonObject?.text("kind").orEmpty()

    private fun JsonObject.text(key: String): String =
        this[key]?.jsonPrimitive?.contentOrNull.orEmpty()

    private fun JsonObject.long(key: String): Long =
        this[key]?.jsonPrimitive?.contentOrNull?.toLongOrNull() ?: 0
}
