package com.hopa.backend.gateway

import com.hopa.backend.ServerConfig
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.newDevice
import com.hopa.backend.harness.newHousehold
import com.hopa.backend.harness.seedHousehold
import com.hopa.backend.module
import com.hopa.backend.pairing.PgAuth
import com.hopa.backend.pairing.Tokens
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.store.PgDevices
import com.hopa.backend.store.PostgresProbe
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.server.testing.testApplication
import java.sql.Timestamp
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class HelloPersistenceTest {
    private val db = PostgresHarness.appDatabase()

    private fun seedAccess(household: String, device: String, member: String): String {
        seedHousehold(db, household, device, member)
        val token = Tokens.mint()
        db.tenant(household) { connection ->
            connection.prepareStatement(
                "insert into access_tokens(id, device_id, household_id, token_hash, expires_at) " +
                    "values (gen_random_uuid(), ?::uuid, ?::uuid, ?, ?)",
            ).use {
                it.setString(1, device)
                it.setString(2, household)
                it.setBytes(3, Tokens.hash(token))
                it.setTimestamp(
                    4,
                    Timestamp.from(Instant.ofEpochMilli(System.currentTimeMillis() + 60_000)),
                )
                it.executeUpdate()
            }
        }
        return token
    }

    private fun hello(deviceId: String, pushToken: String?) = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "device.hello",
        ts = 0,
        from = deviceId,
        body = buildJsonObject {
            put("platform", "android")
            put("name", "Pixel 9")
            put("appVersion", "0.1.0")
            if (pushToken != null) put("pushToken", pushToken)
        },
    )

    private fun pushTokenOf(household: String, device: String): String? =
        db.tenant(household) { connection ->
            connection.prepareStatement("select push_token from devices where id = ?::uuid").use {
                it.setString(1, device)
                it.executeQuery().use { rows -> if (rows.next()) rows.getString(1) else null }
            }
        }

    private fun lastSeenOf(household: String, device: String): Timestamp? =
        db.tenant(household) { connection ->
            connection.prepareStatement("select last_seen_at from devices where id = ?::uuid").use {
                it.setString(1, device)
                it.executeQuery().use { rows -> if (rows.next()) rows.getTimestamp(1) else null }
            }
        }

    @Test
    fun `device hello stores the push token and the last seen time`() = testApplication {
        val household = newHousehold()
        val device = newDevice()
        val token = seedAccess(household, device, UUID.randomUUID().toString())
        application {
            module(
                ServerConfig(
                    version = "0.1.0",
                    auth = PgAuth(db),
                    devices = PgDevices(db),
                    db = PostgresProbe(db),
                ),
            )
        }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice(device, token)

        phone.connect(http)
        phone.send(hello(device, "fcm-token-one"))
        phone.expect("device.hello.ack")

        assertEquals("fcm-token-one", pushTokenOf(household, device))
        assertNotNull(lastSeenOf(household, device))
    }

    @Test
    fun `a later hello replaces the push token`() = testApplication {
        val household = newHousehold()
        val device = newDevice()
        val token = seedAccess(household, device, UUID.randomUUID().toString())
        application {
            module(
                ServerConfig(
                    version = "0.1.0",
                    auth = PgAuth(db),
                    devices = PgDevices(db),
                    db = PostgresProbe(db),
                ),
            )
        }
        val http = createClient { install(WebSockets) }
        val phone = FakeDevice(device, token)

        phone.connect(http)
        phone.send(hello(device, "fcm-token-one"))
        phone.expect("device.hello.ack")
        phone.send(hello(device, "fcm-token-two"))
        phone.expect("device.hello.ack")

        assertEquals("fcm-token-two", pushTokenOf(household, device))
    }
}
