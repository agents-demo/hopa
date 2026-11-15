package com.hopa.backend.trace

import com.hopa.backend.store.Database
import java.security.SecureRandom
import java.sql.Timestamp
import java.time.Instant

/**
 * Spans are best effort: a failed insert is swallowed, because losing a trace
 * must never cost a task. Reads are tenant-scoped like everything else.
 */
class PgTraceStore(
    private val db: Database,
    private val clock: () -> Long = System::currentTimeMillis,
) : TraceRecorder, TraceQuery {
    private val random = SecureRandom()

    override fun <T> span(
        householdId: String,
        traceId: String,
        operation: String,
        deviceId: String?,
        taskId: String?,
        block: () -> T,
    ): T {
        val started = clock()
        return try {
            block().also { record(householdId, traceId, operation, deviceId, taskId, started, "ok") }
        } catch (problem: Throwable) {
            record(householdId, traceId, operation, deviceId, taskId, started, "error")
            throw problem
        }
    }

    override fun spans(householdId: String, traceId: String): List<SpanView> =
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "select operation, started_at, duration_ms, status, device_id, task_id " +
                    "from trace_spans where trace_id = ? order by started_at",
            ).use {
                it.setString(1, traceId)
                it.executeQuery().use { rows ->
                    buildList {
                        while (rows.next()) {
                            add(
                                SpanView(
                                    operation = rows.getString(1),
                                    startedAt = rows.getTimestamp(2).toInstant().toString(),
                                    durationMs = rows.getLong(3),
                                    status = rows.getString(4),
                                    deviceId = rows.getString(5),
                                    taskId = rows.getString(6),
                                ),
                            )
                        }
                    }
                }
            }
        }

    private fun record(
        householdId: String,
        traceId: String,
        operation: String,
        deviceId: String?,
        taskId: String?,
        startedAt: Long,
        status: String,
    ) {
        val spanId = ByteArray(8).also(random::nextBytes)
            .joinToString("") { "%02x".format(it) }
        try {
            db.tenant(householdId) { connection ->
                connection.prepareStatement(
                    "insert into trace_spans(household_id, trace_id, span_id, operation, " +
                        "device_id, task_id, started_at, duration_ms, status) " +
                        "values (?::uuid, ?, ?, ?, ?::uuid, ?::uuid, ?, ?, ?)",
                ).use {
                    it.setString(1, householdId)
                    it.setString(2, traceId)
                    it.setString(3, spanId)
                    it.setString(4, operation)
                    it.setString(5, deviceId)
                    it.setString(6, taskId)
                    it.setTimestamp(7, Timestamp.from(Instant.ofEpochMilli(startedAt)))
                    it.setLong(8, (clock() - startedAt).coerceAtLeast(0))
                    it.setString(9, status)
                    it.executeUpdate()
                }
            }
        } catch (_: Exception) {
            // Tracing is observability, never a reason to refuse a message.
        }
    }
}
