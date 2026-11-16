package com.hopa.backend.store

import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.newDevice
import com.hopa.backend.harness.newHousehold
import com.hopa.backend.harness.seedHousehold
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Test

class TaskEventSeqTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)

    private fun seedTask(household: String, device: String, member: String): String {
        val task = UUID.randomUUID().toString()
        db.tenant(household) { connection ->
            connection.prepareStatement(
                """
                insert into tasks(id, household_id, member_id, from_device, to_device,
                                  message_id, state, trace_id, body, deadline_at)
                values (?::uuid, ?::uuid, ?::uuid, ?::uuid, ?::uuid,
                        gen_random_uuid(), 'queued', ?, '{}', now() + interval '10 minutes')
                """.trimIndent(),
            ).use {
                it.setString(1, task)
                it.setString(2, household)
                it.setString(3, member)
                it.setString(4, device)
                it.setString(5, device)
                it.setString(6, "a".repeat(32))
                it.executeUpdate()
            }
        }
        return task
    }

    @Test
    fun `concurrent events on one task get distinct sequence numbers`() {
        val household = newHousehold()
        val device = newDevice()
        val member = UUID.randomUUID().toString()
        seedHousehold(db, household, device, member)
        val task = seedTask(household, device, member)
        val store = PgTaskStore(db, clock::get)

        val threads = 4
        val perThread = 3
        val pool = Executors.newFixedThreadPool(threads)
        val start = CountDownLatch(1)
        val futures = (1..threads * perThread).map { index ->
            pool.submit {
                start.await()
                store.event(task, household, "e$index", JsonObject(emptyMap()), clock.get())
            }
        }
        start.countDown()
        futures.forEach { it.get() }
        pool.shutdown()

        val seqs = db.tenant(household) { connection ->
            connection.prepareStatement(
                "select seq from task_events where task_id = ?::uuid order by seq",
            ).use {
                it.setString(1, task)
                it.executeQuery().use { rows ->
                    buildList { while (rows.next()) add(rows.getInt(1)) }
                }
            }
        }

        assertEquals((1..threads * perThread).toList(), seqs)
    }
}
