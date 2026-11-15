package com.hopa.backend.pairing

import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.newDevice
import com.hopa.backend.harness.newHousehold
import com.hopa.backend.harness.seedHousehold
import com.hopa.backend.store.PgDevices
import java.sql.Timestamp
import java.time.Instant
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PostgresAuthTest {
    private val db = PostgresHarness.appDatabase()

    private fun seedToken(household: String, device: String, member: String, token: String, expiresAt: Long) {
        seedHousehold(db, household, device, member)
        db.tenant(household) { connection ->
            connection.prepareStatement(
                "insert into access_tokens(id, device_id, household_id, token_hash, expires_at) " +
                    "values (gen_random_uuid(), ?::uuid, ?::uuid, ?, ?)",
            ).use {
                it.setString(1, device)
                it.setString(2, household)
                it.setBytes(3, Tokens.hash(token))
                it.setTimestamp(4, Timestamp.from(Instant.ofEpochMilli(expiresAt)))
                it.executeUpdate()
            }
        }
    }

    @Test
    fun `a live access token resolves to its device and household`() {
        val household = newHousehold()
        val device = newDevice()
        val token = Tokens.mint()
        seedToken(household, device, UUID.randomUUID().toString(), token, System.currentTimeMillis() + 60_000)

        val identity = PgAuth(db).deviceFor(token)

        assertEquals(device, identity!!.deviceId)
        assertEquals(household, identity.householdId)
    }

    @Test
    fun `an expired token resolves to nothing`() {
        val household = newHousehold()
        val token = Tokens.mint()
        seedToken(household, newDevice(), UUID.randomUUID().toString(), token, System.currentTimeMillis() - 1)

        assertNull(PgAuth(db).deviceFor(token))
    }

    @Test
    fun `a revoked or unknown token resolves to nothing`() {
        val household = newHousehold()
        val device = newDevice()
        val token = Tokens.mint()
        seedToken(household, device, UUID.randomUUID().toString(), token, System.currentTimeMillis() + 60_000)

        val auth = PgAuth(db)
        assertEquals(device, auth.deviceFor(token)!!.deviceId)
        db.tenant(household) { connection ->
            connection.createStatement().use { it.executeUpdate("delete from access_tokens") }
        }
        auth.revoke(device)

        assertNull(auth.deviceFor(token))
        assertNull(auth.deviceFor("not-a-token"))
    }

    @Test
    fun `the five second cache still resolves after the row disappears, then expires`() {
        val household = newHousehold()
        val device = newDevice()
        val token = Tokens.mint()
        seedToken(household, device, UUID.randomUUID().toString(), token, System.currentTimeMillis() + 60_000)
        var now = 1_763_212_800_000L
        val auth = PgAuth(db, clock = { now }, cacheTtlMs = 5_000)

        assertEquals(device, auth.deviceFor(token)!!.deviceId)
        db.tenant(household) { connection ->
            connection.createStatement().use { it.executeUpdate("delete from access_tokens") }
        }
        assertEquals("still cached", device, auth.deviceFor(token)!!.deviceId)

        now += 5_001
        assertNull(auth.deviceFor(token))
    }

    @Test
    fun `the directory refuses a device from another household`() {
        val home = newHousehold()
        val other = newHousehold()
        val foreign = newDevice()
        seedHousehold(db, home, newDevice(), UUID.randomUUID().toString())
        seedHousehold(db, other, foreign, UUID.randomUUID().toString())

        val directory = PgDevices(db)

        assertEquals(foreign, directory.lookup(foreign, other)?.deviceId)
        assertNull(directory.lookup(foreign, home))
    }
}
