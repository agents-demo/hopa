package com.hopa.backend.trace

import com.hopa.backend.ServerConfig
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.bodyString
import com.hopa.backend.module
import com.hopa.backend.pairing.PairingService
import com.hopa.backend.pairing.PgAuth
import com.hopa.backend.pairing.TokenIssuer
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.store.PgDevices
import com.hopa.backend.store.PgTaskStore
import com.hopa.backend.store.PostgresProbe
import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import java.util.Base64
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TraceQueryTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)
    private lateinit var auth: PgAuth
    private lateinit var tokens: TokenIssuer
    private lateinit var pairing: PairingService
    private lateinit var devices: PgDevices
    private lateinit var traces: PgTraceStore

    @Before
    fun setUp() {
        auth = PgAuth(db, clock = clock::get)
        tokens = TokenIssuer(db, clock = clock::get, onRevoke = auth::revoke)
        pairing = PairingService(db, clock = clock::get, tokens = tokens)
        devices = PgDevices(db)
        traces = PgTraceStore(db, clock::get)
    }

    private fun config() = ServerConfig(
        version = "0.1.0",
        auth = auth,
        devices = devices,
        db = PostgresProbe(db),
        pairing = pairing,
        bootstrapToken = "boot-secret",
        tokenIssuer = tokens,
        tasks = PgTaskStore(db, clock::get),
        traces = traces,
        traceQuery = traces,
    )

    private data class Session(val deviceId: String, val householdId: String, val access: String)

    private suspend fun HttpClient.claim(name: String, householdId: String? = null): Session {
        val minted = post("/v1/pair/sessions") {
            header("Authorization", "Bearer boot-secret")
            header("X-Forwarded-For", "198.51.100.13")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject {
                put("householdName", name)
                put("memberName", name)
                if (householdId != null) put("householdId", householdId)
            }.toString())
        }.bodyAsText()
        val qr = Json.parseToJsonElement(minted).jsonObject["qr"]!!.jsonPrimitive.content
        val claimed = post("/v1/pair/claim") {
            header("X-Forwarded-For", "198.51.100.13")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject {
                put("session", qr.substringAfter("&p=").substringBefore("&"))
                put("platform", "android")
                put("name", name)
                put("publicKey", Base64.getEncoder().encodeToString(ByteArray(32) { 5 }))
                put("alg", "x25519")
            }.toString())
        }.bodyAsText()
        val body = Json.parseToJsonElement(claimed).jsonObject
        return Session(
            deviceId = body["deviceId"]!!.jsonPrimitive.content,
            householdId = body["householdId"]!!.jsonPrimitive.content,
            access = body["accessToken"]!!.jsonPrimitive.content,
        )
    }

    private fun hello(deviceId: String) = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "device.hello",
        ts = clock.get(),
        from = deviceId,
        body = buildJsonObject { put("platform", "android") },
    )

    private suspend fun ApplicationTestBuilder.connect(session: Session): FakeDevice {
        val http = createClient { install(WebSockets) }
        val device = FakeDevice(session.deviceId, session.access)
        device.connect(http)
        device.send(hello(session.deviceId))
        device.expect("device.hello.ack")
        return device
    }

    @Test
    fun `a round-trip records accept, route, deliver and ack under one trace`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        val pcWs = connect(pc)
        phoneWs.expect("presence")
        val traceparent = "00-${"b".repeat(32)}-${"c".repeat(16)}-01"

        phoneWs.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.create",
                ts = clock.get(),
                trace = traceparent,
                to = pc.deviceId,
                body = buildJsonObject { put("goal", "open settings") },
            ),
        )
        val ack = phoneWs.expect("task.ack")
        assertEquals(traceparent, ack.trace)
        val taskId = ack.bodyString("task")!!
        val delivered = pcWs.expect("task.create")
        pcWs.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.ack",
                ts = clock.get(),
                trace = traceparent,
                to = phone.deviceId,
                task = taskId,
                body = buildJsonObject { put("state", "delivered") },
            ),
        )
        phoneWs.expect("task.ack")

        val response = client.get("/v1/traces/${"b".repeat(32)}") {
            header("Authorization", "Bearer ${phone.access}")
        }
        assertEquals(HttpStatusCode.OK, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        val spans = body["spans"]!!.jsonArray.map { it.jsonObject }
        val operations = spans.map { it["operation"]!!.jsonPrimitive.content }.toSet()
        assertTrue("expected accept/route/deliver/ack, got $operations", operations.containsAll(
            setOf("accept", "route", "deliver", "ack"),
        ))
        assertTrue(spans.all { it["status"]!!.jsonPrimitive.content == "ok" })
    }

    @Test
    fun `another household cannot read the trace`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val other = client.claim("Other")
        val phoneWs = connect(phone)
        val traceparent = "00-${"d".repeat(32)}-${"e".repeat(16)}-01"
        phoneWs.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "ping",
                ts = clock.get(),
                trace = traceparent,
            ),
        )
        phoneWs.expect("pong")

        val response = client.get("/v1/traces/${"d".repeat(32)}") {
            header("Authorization", "Bearer ${other.access}")
        }

        assertEquals(HttpStatusCode.NotFound, response.status)
    }

    @Test
    fun `a missing token is E_AUTH`() = testApplication {
        application { module(config()) }

        val response = client.get("/v1/traces/${"f".repeat(32)}")

        assertEquals(HttpStatusCode.Unauthorized, response.status)
    }

    @Test
    fun `a client traceparent is preserved and echoed`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        connect(pc)
        phoneWs.expect("presence")
        val traceparent = "00-${"1".repeat(32)}-${"2".repeat(16)}-01"

        phoneWs.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.create",
                ts = clock.get(),
                trace = traceparent,
                to = pc.deviceId,
                body = buildJsonObject { put("goal", "open settings") },
            ),
        )

        assertEquals(traceparent, phoneWs.expect("task.ack").trace)
    }

    @Test
    fun `a trace-less message keeps accept and route under the echoed trace`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        connect(pc)
        phoneWs.expect("presence")

        phoneWs.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.create",
                ts = clock.get(),
                to = pc.deviceId,
                body = buildJsonObject { put("goal", "open settings") },
            ),
        )
        val traceparent = phoneWs.expect("task.ack").trace!!
        val traceId = TraceIds.traceId(traceparent)!!

        val response = client.get("/v1/traces/$traceId") {
            header("Authorization", "Bearer ${phone.access}")
        }
        val spans = Json.parseToJsonElement(response.bodyAsText()).jsonObject["spans"]!!.jsonArray
            .map { it.jsonObject["operation"]!!.jsonPrimitive.content }
            .toSet()

        assertTrue("expected accept and route under $traceId, got $spans", spans.containsAll(
            setOf("accept", "route", "deliver"),
        ))
    }

    @Test
    fun `an invalid traceparent is replaced with a fresh one`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        connect(pc)
        phoneWs.expect("presence")

        phoneWs.send(
            Envelope(
                v = 1,
                id = UUID.randomUUID().toString(),
                type = "task.create",
                ts = clock.get(),
                trace = "not-a-traceparent",
                to = pc.deviceId,
                body = buildJsonObject { put("goal", "open settings") },
            ),
        )

        val trace = phoneWs.expect("task.ack").trace!!
        assertTrue(trace.matches(Regex("^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")))
    }
}
