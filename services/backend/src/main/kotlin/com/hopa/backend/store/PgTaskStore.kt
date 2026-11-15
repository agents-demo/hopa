package com.hopa.backend.store

import com.hopa.backend.tasks.TaskRecord
import com.hopa.backend.tasks.TaskStore
import java.nio.charset.StandardCharsets
import java.sql.ResultSet
import java.sql.Timestamp
import java.time.Instant
import javax.sql.rowset.serial.SerialBlob
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put

/**
 * The durable task table and its idempotency window. Every statement runs in a
 * household transaction, so the policies decide what this repository can see.
 */
class PgTaskStore(
    private val db: Database,
    private val clock: () -> Long = System::currentTimeMillis,
) : TaskStore {
    override fun remember(householdId: String, messageId: String, task: TaskRecord): Boolean {
        val now = clock()
        return db.tenant(householdId) { connection ->
            val response = buildJsonObject {
                put("taskId", task.id)
                put("state", task.state)
            }.toString()
            val claimed = connection.prepareStatement(
                """
                insert into idempotency_keys(household_id, message_id, response, expires_at)
                values (?::uuid, ?::uuid, ?::jsonb, ?)
                on conflict (household_id, message_id) do update
                  set response = excluded.response, expires_at = excluded.expires_at
                  where idempotency_keys.expires_at <= ?
                """.trimIndent(),
            ).use {
                it.setString(1, householdId)
                it.setString(2, messageId)
                it.setString(3, response)
                it.setTimestamp(4, timestamp(now + IDEMPOTENCY_MS))
                it.setTimestamp(5, timestamp(now))
                it.executeUpdate()
            }
            if (claimed != 1) return@tenant false

            connection.prepareStatement(
                """
                insert into tasks(id, household_id, member_id, from_device, to_device,
                                  message_id, state, trace_id, body, deadline_at,
                                  created_at, updated_at)
                values (?::uuid, ?::uuid, ?::uuid, ?::uuid, ?::uuid, ?::uuid,
                        ?, ?, ?, ?, ?, ?)
                """.trimIndent(),
            ).use {
                it.setString(1, task.id)
                it.setString(2, task.householdId)
                it.setString(3, task.memberId)
                it.setString(4, task.from)
                it.setString(5, task.to)
                it.setString(6, task.messageId)
                it.setString(7, task.state)
                it.setString(8, task.trace)
                it.setBytes(9, task.body.toString().toByteArray(StandardCharsets.UTF_8))
                it.setTimestamp(10, timestamp(task.deadlineAt))
                it.setTimestamp(11, timestamp(now))
                it.setTimestamp(12, timestamp(now))
                it.executeUpdate()
            }
            true
        }
    }

    override fun recall(householdId: String, messageId: String): TaskRecord? {
        val taskId = db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "select response->>'taskId' as task_id from idempotency_keys " +
                    "where household_id = ?::uuid and message_id = ?::uuid and expires_at > ?",
            ).use {
                it.setString(1, householdId)
                it.setString(2, messageId)
                it.setTimestamp(3, timestamp(clock()))
                it.executeQuery().use { rows -> if (rows.next()) rows.getString(1) else null }
            }
        } ?: return null

        return find(taskId, householdId)
    }

    override fun find(taskId: String, householdId: String): TaskRecord? =
        db.tenant(householdId) { connection ->
            connection.prepareStatement("$SELECT where id = ?::uuid").use {
                it.setString(1, taskId)
                it.executeQuery().use { rows -> if (rows.next()) map(rows) else null }
            }
        }

    override fun update(task: TaskRecord) {
        db.tenant(task.householdId) { connection ->
            connection.prepareStatement(
                "update tasks set state = ?, updated_at = ? where id = ?::uuid",
            ).use {
                it.setString(1, task.state)
                it.setTimestamp(2, timestamp(clock()))
                it.setString(3, task.id)
                it.executeUpdate()
            }
        }
    }

    override fun pendingFor(deviceId: String, householdId: String, now: Long): List<TaskRecord> =
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "$SELECT where to_device = ?::uuid and state in ('queued','delivered') " +
                    "and deadline_at > ? order by created_at",
            ).use {
                it.setString(1, deviceId)
                it.setTimestamp(2, timestamp(now))
                it.executeQuery().use { rows -> buildList { while (rows.next()) add(map(rows)) } }
            }
        }

    override fun markDelivered(taskId: String, householdId: String) {
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "update tasks set state = 'delivered', updated_at = ? where id = ?::uuid",
            ).use {
                it.setTimestamp(1, timestamp(clock()))
                it.setString(2, taskId)
                it.executeUpdate()
            }
        }
    }

    override fun event(taskId: String, householdId: String, kind: String, body: JsonObject, at: Long) {
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                """
                insert into task_events(task_id, household_id, seq, kind, body, at)
                values (?::uuid, ?::uuid,
                        (select coalesce(max(seq), 0) + 1 from task_events where task_id = ?::uuid),
                        ?, ?, ?)
                """.trimIndent(),
            ).use {
                it.setString(1, taskId)
                it.setString(2, householdId)
                it.setString(3, taskId)
                it.setString(4, kind)
                it.setBytes(5, body.toString().toByteArray(StandardCharsets.UTF_8))
                it.setTimestamp(6, timestamp(at))
                it.executeUpdate()
            }
        }
    }

    private fun map(rows: ResultSet): TaskRecord = TaskRecord(
        id = rows.getString("id"),
        householdId = rows.getString("household_id"),
        memberId = rows.getString("member_id"),
        from = rows.getString("from_device"),
        to = rows.getString("to_device"),
        messageId = rows.getString("message_id"),
        trace = rows.getString("trace_id"),
        ts = rows.getTimestamp("created_at").toInstant().toEpochMilli(),
        body = Json.parseToJsonElement(
            String(rows.getBytes("body"), StandardCharsets.UTF_8),
        ).jsonObject,
        state = rows.getString("state"),
        deadlineAt = rows.getTimestamp("deadline_at").toInstant().toEpochMilli(),
    )

    private fun timestamp(millis: Long): Timestamp = Timestamp.from(Instant.ofEpochMilli(millis))

    private companion object {
        const val IDEMPOTENCY_MS = 24L * 60 * 60 * 1000
        const val SELECT =
            "select id, household_id, member_id, from_device, to_device, message_id, " +
                "state, trace_id, body, deadline_at, created_at from tasks"
    }
}
