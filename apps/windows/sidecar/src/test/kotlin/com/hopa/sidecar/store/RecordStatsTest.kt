package com.hopa.sidecar.store

import java.time.Instant
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class RecordStatsTest {
    @Test
    fun history_flattens_turns_with_the_conversation_title() {
        val turns = listOf(
            turn("c1", "run-1", 100, record(executed = true), record(executed = false)),
            turn("c2", "run-2", 200, record(executed = true)),
        )

        val entries = RecordStats.history(turns) { id -> "title-$id" }

        assertEquals(2, entries.size)
        assertEquals("title-c1", entries[0].title)
        assertEquals(2, entries[0].steps)
        assertEquals(1, entries[0].executed)
        assertEquals(1, entries[0].failed)
        assertEquals("run-2", entries[1].runId)
    }

    @Test
    fun usage_counts_executed_failed_payments_and_top_actions() {
        val now = Instant.parse("2026-11-24T12:00:00Z").toEpochMilli()
        val recent = Instant.ofEpochMilli(now - 1000).toString()
        val old = Instant.ofEpochMilli(now - 8L * 24 * 60 * 60 * 1000).toString()
        val turns = listOf(
            turn(
                "c1",
                "run-1",
                now,
                record(executed = true, kind = "ui.tap", timestamp = recent),
                record(executed = false, kind = "ui.type", classification = "payment", timestamp = recent),
                record(executed = true, kind = "ui.tap", timestamp = old),
            ),
        )

        val usage = RecordStats.usage(turns, now)

        assertEquals(3, usage.total)
        assertEquals(2, usage.executed)
        assertEquals(1, usage.failed)
        assertEquals(1, usage.payments)
        assertEquals(2, usage.lastSevenDays)
        assertEquals("ui.tap" to 2, usage.topActions.first())
    }

    private fun turn(conversationId: String, runId: String, createdAt: Long, vararg records: JsonObject) =
        buildJsonObject {
            put("conversationId", conversationId)
            put("runId", runId)
            put("createdAt", createdAt)
            put("records", JsonArray(records.toList()))
        }

    private fun record(
        executed: Boolean,
        kind: String = "ui.tap",
        classification: String = "read",
        timestamp: String = "",
    ) = buildJsonObject {
        put("executed", executed)
        put("classification", classification)
        put("timestamp", timestamp)
        put("action", buildJsonObject { put("kind", kind) })
    }
}
