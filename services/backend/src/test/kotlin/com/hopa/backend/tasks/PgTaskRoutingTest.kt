package com.hopa.backend.tasks

import com.hopa.backend.ServerConfig
import com.hopa.backend.gateway.DeviceRegistry
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.bodyString
import com.hopa.backend.harness.newDevice
import com.hopa.backend.harness.newHousehold
import com.hopa.backend.harness.seedHousehold
import com.hopa.backend.http.RateLimiter
import com.hopa.backend.log.EventLog
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
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import java.sql.Timestamp
import java.time.Instant
import java.util.Base64
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class PgTaskRoutingTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)
    private lateinit var auth: PgAuth
    private lateinit var tokens: TokenIssuer
    private lateinit var pairing: PairingService
    private lateinit var devices: PgDevices
    private lateinit var store: PgTaskStore
    private val events = mutableListOf<Pair<String, Map<String, String>>>()

    @Before
    fun setUp() {
        auth = PgAuth(db, clock = clock::get)
        tokens = TokenIssuer(db, clock = clock::get, onRevoke = auth::revoke)
        pairing = PairingService(db, clock = clock::get, tokens = tokens)
        devices = PgDevices(db)
        store = PgTaskStore(db, clock = clock::get)
        events.clear()
    }

    private fun config(
        taskStore: TaskStore = store,
        messageLimit: RateLimiter = RateLimiter(20, 1_000, clock::get),
    ) = ServerConfig(
        version = "0.1.0",
        auth = auth,
        devices = devices,
        db = PostgresProbe(db),
        pairing = pairing,
        bootstrapToken = "boot-secret",
        tokenIssuer = tokens,
        tasks = taskStore,
        messageLimit = messageLimit,
        log = EventLog { name, fields -> events += name to fields },
    )

    private data class Session(val deviceId: String, val householdId: String, val access: String)

    private suspend fun HttpClient.claim(name: String, householdId: String? = null): Session {
        val minted = post("/v1/pair/sessions") {
            header("Authorization", "Bearer boot-secret")
            header("X-Forwarded-For", "198.51.100.9")
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
            header("X-Forwarded-For", "198.51.100.9")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject {
                put("session", session)
                put("platform", "android")
                put("name", name)
                put("publicKey", Base64.getEncoder().encodeToString(ByteArray(32) { 3 }))
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
        body = buildJsonObject {
            put("platform", "android")
            put("name", "Pixel 9")
            put("appVersion", "0.1.0")
        },
    )

    private fun create(to: String, id: String = UUID.randomUUID().toString()) = Envelope(
        v = 1,
        id = id,
        type = "task.create",
        ts = clock.get(),
        to = to,
        body = buildJsonObject { put("goal", "open the settings app") },
    )

    private suspend fun ApplicationTestBuilder.connect(session: Session): FakeDevice {
        val http = createClient { install(WebSockets) }
        val device = FakeDevice(session.deviceId, session.access)
        device.connect(http)
        device.send(hello(session.deviceId))
        device.expect("device.hello.ack")
        return device
    }

    private fun taskState(taskId: String, household: String): String? =
        db.tenant(household) { connection ->
            connection.prepareStatement("select state from tasks where id = ?::uuid").use {
                it.setString(1, taskId)
                it.executeQuery().use { rows -> if (rows.next()) rows.getString(1) else null }
            }
        }

    private fun taskCount(household: String): Int =
        db.tenant(household) { connection ->
            connection.createStatement().use { statement ->
                statement.executeQuery("select count(*) from tasks").use { rows -> rows.next(); rows.getInt(1) }
            }
        }

    private fun eventCount(taskId: String, household: String, kind: String): Int =
        db.tenant(household) { connection ->
            connection.prepareStatement(
                "select count(*) from task_events where task_id = ?::uuid and kind = ?",
            ).use {
                it.setString(1, taskId)
                it.setString(2, kind)
                it.executeQuery().use { rows -> rows.next(); rows.getInt(1) }
            }
        }

    @Test
    fun `a round-trip writes the task, the event and the ack`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        val pcWs = connect(pc)
        phoneWs.expect("presence")

        val message = create(pc.deviceId)
        phoneWs.send(message)

        val ack = phoneWs.expect("task.ack")
        val taskId = ack.bodyString("task")!!
        assertEquals("delivered", ack.bodyString("state"))
        assertEquals("false", ack.bodyString("duplicate"))

        val delivered = pcWs.expect("task.create")
        assertEquals(message.id, delivered.id)
        assertEquals(taskId, delivered.task)
        assertEquals(message.body, delivered.body)
        assertEquals("delivered", taskState(taskId, phone.householdId))
        assertTrue(eventCount(taskId, phone.householdId, "create") >= 1)
    }

    @Test
    fun `the same message id three times creates one row and one delivery`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        val pcWs = connect(pc)
        phoneWs.expect("presence")

        val message = create(pc.deviceId)
        phoneWs.send(message)
        val first = phoneWs.expect("task.ack")
        pcWs.expect("task.create")
        phoneWs.send(message)
        val second = phoneWs.expect("task.ack")
        phoneWs.send(message)
        val third = phoneWs.expect("task.ack")

        assertEquals(first.bodyString("task"), second.bodyString("task"))
        assertEquals(first.bodyString("task"), third.bodyString("task"))
        assertEquals("true", second.bodyString("duplicate"))
        assertEquals("true", third.bodyString("duplicate"))
        pcWs.expectNothing("task.create")
        assertEquals(1, taskCount(phone.householdId))
    }

    @Test
    fun `a cross-household target is refused and leaves no row`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Levi")
        val other = client.claim("Other")
        val phoneWs = connect(phone)

        phoneWs.send(create(other.deviceId))

        assertEquals("E_TENANT", phoneWs.expect("error").bodyString("code"))
        assertEquals(0, taskCount(phone.householdId))
        assertTrue(events.any { it.first == "tenant_refused" })
    }

    @Test
    fun `a queued task survives a restart and is delivered on hello`() = testApplication {
        application { module(config(taskStore = PgTaskStore(db, clock::get))) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val identity = auth.deviceFor(phone.access)!!
        val beforeRestart = TaskRouter(PgTaskStore(db, clock::get), DeviceRegistry(), devices)
        val routed = beforeRestart.route(identity, create(pc.deviceId))
        assertTrue(routed is RouteResult.Accepted)
        val taskId = (routed as RouteResult.Accepted).task.id
        assertEquals("queued", routed.task.state)

        val pcWs = connect(pc)

        val delivered = pcWs.expect("task.create")
        assertEquals(taskId, delivered.task)
        assertEquals("delivered", taskState(taskId, phone.householdId))
    }

    @Test
    fun `a task past its deadline is never delivered`() = testApplication {
        application { module(config()) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val identity = auth.deviceFor(phone.access)!!
        val router = TaskRouter(store, DeviceRegistry(), devices)
        router.route(identity, create(pc.deviceId))
        db.tenant(phone.householdId) { connection ->
            connection.createStatement().use {
                it.executeUpdate("update tasks set deadline_at = now() - interval '1 minute'")
            }
        }

        val pcWs = connect(pc)

        pcWs.expectNothing("task.create")
    }

    @Test
    fun `the second message in one window is E_RATE`() = testApplication {
        application { module(config(messageLimit = RateLimiter(1, 60_000, clock::get))) }
        val phone = client.claim("Phone")
        val pc = client.claim("PC", phone.householdId)
        val phoneWs = connect(phone)
        connect(pc)

        phoneWs.send(create(pc.deviceId))
        phoneWs.expect("task.ack")
        phoneWs.send(create(pc.deviceId))

        assertEquals("E_RATE", phoneWs.expect("error").bodyString("code"))
    }

    @Test
    fun `idempotency expires after twenty four hours`() {
        val household = newHousehold()
        val device = newDevice()
        val member = UUID.randomUUID().toString()
        seedHousehold(db, household, device, member)
        val messageId = UUID.randomUUID().toString()
        val task = TaskRecord(
            id = UUID.randomUUID().toString(),
            householdId = household,
            memberId = member,
            from = device,
            to = device,
            messageId = messageId,
            trace = "a".repeat(32),
            ts = clock.get(),
            body = JsonObject(emptyMap()),
            state = "queued",
            deadlineAt = clock.get() + 600_000,
        )
        val tasks = PgTaskStore(db, clock::get)
        tasks.remember(household, messageId, task)

        assertEquals(task.id, tasks.recall(household, messageId)?.id)
        db.tenant(household) { connection ->
            connection.prepareStatement("update idempotency_keys set expires_at = ?").use {
                it.setTimestamp(1, Timestamp.from(Instant.ofEpochMilli(clock.get() - 1)))
                it.executeUpdate()
            }
        }
        assertNull(tasks.recall(household, messageId))
    }
}
