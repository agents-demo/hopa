package com.hopa.backend.pairing

import com.hopa.backend.ServerConfig
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.module
import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.testApplication
import java.time.Instant
import java.util.Base64
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PairingHttpTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)

    private fun config() = ServerConfig(
        version = "0.1.0",
        bootstrapToken = "boot-secret",
        pairing = PairingService(db, clock = clock::get),
    )

    private suspend fun HttpClient.mint(
        household: String = "Levi",
        member: String = "Amir",
        address: String = "198.51.100.1",
        bootstrap: String = "boot-secret",
    ): HttpResponse = post("/v1/pair/sessions") {
        header(HttpHeaders.Authorization, "Bearer $bootstrap")
        header("X-Forwarded-For", address)
        contentType(ContentType.Application.Json)
        setBody(buildJsonObject {
            put("householdName", household)
            put("memberName", member)
        }.toString())
    }

    private suspend fun HttpClient.claim(
        session: String,
        address: String = "198.51.100.1",
    ): HttpResponse = post("/v1/pair/claim") {
        header("X-Forwarded-For", address)
        contentType(ContentType.Application.Json)
        setBody(buildJsonObject {
            put("session", session)
            put("platform", "android")
            put("name", "Pixel 9")
            put("publicKey", Base64.getEncoder().encodeToString(ByteArray(32) { 1 }))
            put("alg", "x25519")
            put("pushToken", "fcm-token")
        }.toString())
    }

    private fun qrOf(response: String): String =
        Json.parseToJsonElement(response).jsonObject["qr"]!!.jsonPrimitive.content

    private fun sessionOf(qr: String): String = qr.substringAfter("&p=").substringBefore("&")

    private suspend fun errorCode(response: HttpResponse): String =
        Json.parseToJsonElement(response.bodyAsText()).jsonObject["code"]!!.jsonPrimitive.content

    @Test
    fun `a bootstrap token mints a QR session that expires in five minutes`() = testApplication {
        application { module(config()) }

        val response = client.mint()

        assertEquals(HttpStatusCode.Created, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        val qr = body["qr"]!!.jsonPrimitive.content
        assertTrue(qr.startsWith("hopa://pair?v=1&h="))
        assertTrue(qr.contains("&p="))
        assertTrue(qr.endsWith("/v1/gateway"))
        assertEquals(
            clock.get() + 300_000,
            Instant.parse(body["expiresAt"]!!.jsonPrimitive.content).toEpochMilli(),
        )

        val plain = sessionOf(qr)
        val household = qr.substringAfter("h=").substringBefore("&")
        val stored = db.tenant(household) { connection ->
            connection.createStatement().use { statement ->
                statement.executeQuery("select encode(code_hash,'hex') from pairing_sessions").use { rows ->
                    rows.next()
                    rows.getString(1)
                }
            }
        }
        assertNotEquals(plain, stored)
        assertEquals(Tokens.hex(Tokens.hash(plain)), stored)
    }

    @Test
    fun `a claim creates the device and returns working opaque tokens`() = testApplication {
        application { module(config()) }
        val session = sessionOf(qrOf(client.mint().bodyAsText()))

        val response = client.claim(session)

        assertEquals(HttpStatusCode.Created, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        val access = body["accessToken"]!!.jsonPrimitive.content
        val refresh = body["refreshToken"]!!.jsonPrimitive.content
        val household = body["householdId"]!!.jsonPrimitive.content
        assertTrue(access.length >= 43)

        val hashes = db.tenant(household) { connection ->
            connection.createStatement().use { statement ->
                statement.executeQuery(
                    "select encode(token_hash,'hex') from access_tokens " +
                        "union all select encode(token_hash,'hex') from refresh_tokens",
                ).use { rows ->
                    buildList { while (rows.next()) add(rows.getString(1)) }
                }
            }
        }
        assertFalse(hashes.contains(access))
        assertTrue(hashes.contains(Tokens.hex(Tokens.hash(access))))
        assertTrue(hashes.contains(Tokens.hex(Tokens.hash(refresh))))
    }

    @Test
    fun `a session cannot be claimed twice`() = testApplication {
        application { module(config()) }
        val session = sessionOf(qrOf(client.mint().bodyAsText()))

        assertEquals(HttpStatusCode.Created, client.claim(session).status)
        val again = client.claim(session)

        assertEquals(HttpStatusCode.BadRequest, again.status)
        assertEquals("E_SCHEMA", errorCode(again))
    }

    @Test
    fun `an expired or unknown session is refused`() = testApplication {
        application { module(config()) }
        val session = sessionOf(qrOf(client.mint().bodyAsText()))
        clock.addAndGet(300_001)

        val expired = client.claim(session)
        val unknown = client.claim(Tokens.mint())

        assertEquals(HttpStatusCode.BadRequest, expired.status)
        assertEquals(HttpStatusCode.BadRequest, unknown.status)
    }

    @Test
    fun `a missing or wrong bootstrap token is E_AUTH`() = testApplication {
        application { module(config()) }

        val none = client.post("/v1/pair/sessions") {
            contentType(ContentType.Application.Json)
            setBody("{}")
        }
        val wrong = client.mint(bootstrap = "nope")

        assertEquals(HttpStatusCode.Unauthorized, none.status)
        assertEquals("E_AUTH", errorCode(none))
        assertEquals(HttpStatusCode.Unauthorized, wrong.status)
    }

    @Test
    fun `a session minted for an existing household joins it`() = testApplication {
        application { module(config()) }
        val first = Json.parseToJsonElement(
            client.claim(sessionOf(qrOf(client.mint().bodyAsText()))).bodyAsText(),
        ).jsonObject
        val household = first["householdId"]!!.jsonPrimitive.content

        val join = client.post("/v1/pair/sessions") {
            header(HttpHeaders.Authorization, "Bearer boot-secret")
            header("X-Forwarded-For", "198.51.100.2")
            contentType(ContentType.Application.Json)
            setBody(
                """{"householdName":"Levi","memberName":"PC","householdId":"$household"}""",
            )
        }
        val second = Json.parseToJsonElement(
            client.claim(sessionOf(qrOf(join.bodyAsText()))).bodyAsText(),
        ).jsonObject

        assertEquals(household, second["householdId"]!!.jsonPrimitive.content)
        assertNotEquals(
            first["deviceId"]!!.jsonPrimitive.content,
            second["deviceId"]!!.jsonPrimitive.content,
        )
    }

    @Test
    fun `the sixth session from one address in a minute is E_RATE`() = testApplication {
        application { module(config()) }

        repeat(5) {
            assertNotEquals(
                HttpStatusCode.TooManyRequests,
                client.mint(address = "203.0.113.7").status,
            )
        }
        val sixth = client.mint(address = "203.0.113.7")

        assertEquals(HttpStatusCode.TooManyRequests, sixth.status)
        assertEquals("E_RATE", errorCode(sixth))
    }

    @Test
    fun `an empty household name is E_SCHEMA`() = testApplication {
        application { module(config()) }

        val response = client.mint(household = "")

        assertEquals(HttpStatusCode.BadRequest, response.status)
        assertEquals("E_SCHEMA", errorCode(response))
    }

    @Test
    fun `an oversized member name is E_SCHEMA`() = testApplication {
        application { module(config()) }

        val response = client.mint(member = "a".repeat(201))

        assertEquals(HttpStatusCode.BadRequest, response.status)
        assertEquals("E_SCHEMA", errorCode(response))
    }

    @Test
    fun `a request body over the cap is refused with 413`() = testApplication {
        application { module(config()) }

        val response = client.post("/v1/pair/claim") {
            contentType(ContentType.Application.Json)
            setBody("""{"session":"${"a".repeat(70_000)}","platform":"android","name":"x","publicKey":"AAAA","alg":"x25519"}""")
        }

        assertEquals(HttpStatusCode.PayloadTooLarge, response.status)
    }
}
