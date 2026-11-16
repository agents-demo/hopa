package com.hopa.backend.store

import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.newDevice
import com.hopa.backend.harness.newHousehold
import com.hopa.backend.harness.seedHousehold
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Test

class QueueDepthTest {
    private val db = PostgresHarness.appDatabase()

    private fun seedTask(household: String, device: String, member: String, deadline: String) {
        db.tenant(household) { connection ->
            connection.prepareStatement(
                """
                insert into tasks(id, household_id, member_id, from_device, to_device,
                                  message_id, state, trace_id, body, deadline_at)
                values (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid, ?::uuid,
                        gen_random_uuid(), 'queued', ?, '{}', $deadline)
                """.trimIndent(),
            ).use {
                it.setString(1, household)
                it.setString(2, member)
                it.setString(3, device)
                it.setString(4, device)
                it.setString(5, "a".repeat(32))
                it.executeUpdate()
            }
        }
    }

    @Test
    fun `queue depth counts only tasks that can still be delivered`() {
        val household = newHousehold()
        val device = newDevice()
        val member = UUID.randomUUID().toString()
        seedHousehold(db, household, device, member)
        seedTask(household, device, member, "now() + interval '5 minutes'")
        seedTask(household, device, member, "now() - interval '1 minute'")

        assertEquals(1, PostgresProbe(db).queueDepth(household))
    }
}
