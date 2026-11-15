package com.hopa.backend.push

import com.hopa.backend.ServerConfig
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.FakeFcm
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.bodyString
import com.hopa.backend.module
import com.hopa.backend.pairing.PairingService
import com.hopa.backend.pairing.PgAuth
import com.hopa.backend.pairing.TokenIssuer
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.store.PgDevices
import com.hopa.backend.store.PostgresProbe
import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import java.util.Base64
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class WakeTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)
    private lateinit var auth: PgAuth
    private lateinit var tokens: TokenIssuer
    private lateinit var pairing: PairingService
    private lateinit var devices: PgDevices

    @Before
    fun setUp() {
        auth = PgAuth(db, clock = clock::get)
        tokens = TokenIssuer(db, clock = clock::get, onRevoke = auth::revoke)
        pairing = PairingService(db, clock = clock::get, tokens = tokens)
        devices = PgDevices(db)
    }

    private fun config(push: PushPort) = ServerConfig(
        version = "0.1.0",
        auth = auth,
        devices = devices,
        db = PostgresProbe(db),
        pairing = pairing,
        bootstrapToken = "boot-secret",
        tokenIssuer = tokens,
        push = push,
    )

    private data class Session(val deviceId: String, val householdId: String, val access: String)

    private suspend fun HttpClient.claim(
        name: String,
        householdId: String? = null,
        pushToken: String,
    ): Session {
        val minted = post("/v1/pair/sessions") {
            header("Authorization", "Bearer boot-secret")
            header("X-Forwarded-For", "198.51.100.11")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject {
                put("householdName", name)
                put("memberName", name)
                if (householdId != null) put("householdId", householdId)
            }.toString())
        }.bodyAsText()
        val qr = Json.parseToJsonElement(minted).jsonObject["qr"]!!.jsonPrimitive.content
        val session = qr.substringAfter("&p=").substringBefore("&")
        val claimed = post("/v1/pair/claim") {
            header("X-Forwarded-For", "198.51.100.11")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject {
                put("session", session)
                put("platform", "android")
                put("name", name)
                put("publicKey", Base64.getEncoder().encodeToString(ByteArray(32) { 4 }))
                put("alg", "x25519")
                put("pushToken", pushToken)
            }.toString())
        }.bodyAsText()
        val body = Json.parseToJsonElement(claimed).jsonObject
        return Session(
            deviceId = body["deviceId"]!!.jsonPrimitive.content,
            householdId = body["householdId"]!!.jsonPrimitive.content,
            access = body["accessToken"]!!.jsonPrimitive.content,
        )
    }

    private fun hello(deviceId: String, pushToken: String?) = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "device.hello",
        ts = clock.get(),
        from = deviceId,
        body = buildJsonObject {
            put("platform", "android")
            put("name", "Pixel 9")
            put("appVersion", "0.1.0")
            if (pushToken != null) put("pushToken", pushToken)
        },
    )

    private suspend fun ApplicationTestBuilder.connect(
        session: Session,
        pushToken: String? = null,
    ): FakeDevice {
        val http = createClient { install(WebSockets) }
        val device = FakeDevice(session.deviceId, session.access)
        device.connect(http)
        device.send(hello(session.deviceId, pushToken))
        device.expect("device.hello.ack")
        return device
    }

    private fun create(to: String) = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "task.create",
        ts = clock.get(),
        to = to,
        body = buildJsonObject { put("goal", "find the lease pdf") },
    )

    private fun pushTokenOf(household: String, device: String): String? =
        db.tenant(household) { connection ->
            connection.prepareStatement("select push_token from devices where id = ?::uuid").use {
                it.setString(1, device)
                it.executeQuery().use { rows -> if (rows.next()) rows.getString(1) else null }
            }
        }

    @Test
    fun `an offline target gets one data-only high-priority wake`() = testApplication {
        val fcm = FakeFcm()
        try {
            application { module(config(fcm.push())) }
            val phone = client.claim("Phone", pushToken = "fcm-phone")
            val pc = client.claim("PC", phone.householdId, pushToken = "fcm-token")
            val phoneWs = connect(phone)

            phoneWs.send(create(pc.deviceId))
            val ack = phoneWs.expect("task.ack")

            assertEquals("queued", ack.bodyString("state"))
            assertEquals(1, fcm.requests.size)
            val message = Json.parseToJsonElement(fcm.requests.single())
                .jsonObject["message"]!!.jsonObject
            assertEquals("fcm-token", message["token"]!!.jsonPrimitive.content)
            val android = message["android"]!!.jsonObject
            assertEquals("high", android["priority"]!!.jsonPrimitive.content)
            assertEquals("300s", android["ttl"]!!.jsonPrimitive.content)
            assertEquals(setOf("taskId", "traceId"), message["data"]!!.jsonObject.keys)
            assertFalse(fcm.requests.single().contains("lease"))
        } finally {
            fcm.close()
        }
    }

    @Test
    fun `an online target is delivered and never woken`() = testApplication {
        val fcm = FakeFcm()
        try {
            application { module(config(fcm.push())) }
            val phone = client.claim("Phone", pushToken = "fcm-phone")
            val pc = client.claim("PC", phone.householdId, pushToken = "fcm-token")
            val phoneWs = connect(phone)
            connect(pc)
            phoneWs.expect("presence")

            phoneWs.send(create(pc.deviceId))
            phoneWs.expect("task.ack")

            assertTrue(fcm.requests.isEmpty())
        } finally {
            fcm.close()
        }
    }

    @Test
    fun `the seventh wake in a minute is suppressed`() = testApplication {
        val fcm = FakeFcm()
        try {
            application { module(config(fcm.push())) }
            val phone = client.claim("Phone", pushToken = "fcm-phone")
            val pc = client.claim("PC", phone.householdId, pushToken = "fcm-token")
            val phoneWs = connect(phone)

            repeat(7) {
                phoneWs.send(create(pc.deviceId))
                phoneWs.expect("task.ack")
            }

            assertEquals(6, fcm.requests.size)
        } finally {
            fcm.close()
        }
    }

    @Test
    fun `the same task never wakes twice`() {
        val fcm = FakeFcm()
        try {
            val push = GuardedPush(
                com.hopa.backend.push.FcmSender(
                    projectId = "hopa-test",
                    baseUrl = fcm.url,
                    auth = StaticFcmAuth("test-token"),
                ),
                clock = clock::get,
            )

            push.wake("dev", "task-1", "trace-1", "fcm-token")
            push.wake("dev", "task-1", "trace-1", "fcm-token")

            assertEquals(1, fcm.requests.size)
        } finally {
            fcm.close()
        }
    }

    @Test
    fun `an unregistered token is cleared and the next hello restores it`() = testApplication {
        val fcm = FakeFcm()
        try {
            application { module(config(fcm.push())) }
            val phone = client.claim("Phone", pushToken = "fcm-phone")
            val pc = client.claim("PC", phone.householdId, pushToken = "dead-token")
            val phoneWs = connect(phone)

            phoneWs.send(create(pc.deviceId))
            phoneWs.expect("task.ack")

            assertNull(pushTokenOf(phone.householdId, pc.deviceId))

            connect(pc, pushToken = "fresh-token")
            assertEquals("fresh-token", pushTokenOf(phone.householdId, pc.deviceId))
        } finally {
            fcm.close()
        }
    }
}
