package com.hopa.backend.pairing

import com.hopa.backend.ServerConfig
import com.hopa.backend.harness.FakeDevice
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.harness.bodyString
import com.hopa.backend.module
import com.hopa.backend.store.PgDevices
import com.hopa.backend.store.PostgresProbe
import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.testApplication
import java.util.Base64
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Before
import org.junit.Test

class TokenRotationTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)
    private lateinit var auth: PgAuth
    private lateinit var tokens: TokenIssuer
    private lateinit var pairing: PairingService

    @Before
    fun setUp() {
        auth = PgAuth(db, clock = clock::get)
        tokens = TokenIssuer(db, clock = clock::get, onRevoke = auth::revoke)
        pairing = PairingService(db, clock = clock::get, tokens = tokens)
    }

    private fun config() = ServerConfig(
        version = "0.1.0",
        auth = auth,
        devices = PgDevices(db),
        db = PostgresProbe(db),
        pairing = pairing,
        bootstrapToken = "boot-secret",
        tokenIssuer = tokens,
    )

    private data class Session(val deviceId: String, val access: String, val refresh: String)

    private suspend fun HttpClient.mint(): String =
        post("/v1/pair/sessions") {
            header("Authorization", "Bearer boot-secret")
            header("X-Forwarded-For", "198.51.100.7")
            contentType(ContentType.Application.Json)
            setBody("""{"householdName":"Levi","memberName":"Amir"}""")
        }.bodyAsText().let { Json.parseToJsonElement(it).jsonObject["qr"]!!.jsonPrimitive.content }

    private suspend fun HttpClient.claim(session: String): Session {
        val response = post("/v1/pair/claim") {
            header("X-Forwarded-For", "198.51.100.7")
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject {
                put("session", session)
                put("platform", "android")
                put("name", "Pixel 9")
                put("publicKey", Base64.getEncoder().encodeToString(ByteArray(32) { 2 }))
                put("alg", "x25519")
            }.toString())
        }
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        return Session(
            deviceId = body["deviceId"]!!.jsonPrimitive.content,
            access = body["accessToken"]!!.jsonPrimitive.content,
            refresh = body["refreshToken"]!!.jsonPrimitive.content,
        )
    }

    private suspend fun claimOnce(client: HttpClient): Session {
        val qr = client.mint()
        return client.claim(qr.substringAfter("&p=").substringBefore("&"))
    }

    private suspend fun HttpClient.refresh(token: String): HttpResponse =
        post("/v1/token/refresh") {
            contentType(ContentType.Application.Json)
            setBody("""{"refreshToken":"$token"}""")
        }

    @Test
    fun `refresh rotates both tokens and the new pair works`() = testApplication {
        application { module(config()) }
        val first = claimOnce(client)

        val rotated = client.refresh(first.refresh)

        assertEquals(HttpStatusCode.OK, rotated.status)
        val body = Json.parseToJsonElement(rotated.bodyAsText()).jsonObject
        val newRefresh = body["refreshToken"]!!.jsonPrimitive.content
        val newAccess = body["accessToken"]!!.jsonPrimitive.content
        assertNotEquals(first.refresh, newRefresh)
        assertNotEquals(first.access, newAccess)
        assertEquals(HttpStatusCode.OK, client.refresh(newRefresh).status)
    }

    @Test
    fun `reusing a rotated refresh token revokes the whole device family`() = testApplication {
        application { module(config()) }
        val first = claimOnce(client)
        val rotated = Json.parseToJsonElement(client.refresh(first.refresh).bodyAsText()).jsonObject
        val newRefresh = rotated["refreshToken"]!!.jsonPrimitive.content
        val newAccess = rotated["accessToken"]!!.jsonPrimitive.content

        val reuse = client.refresh(first.refresh)

        assertEquals(HttpStatusCode.Unauthorized, reuse.status)
        assertEquals(HttpStatusCode.Unauthorized, client.refresh(newRefresh).status)

        val http = createClient { install(WebSockets) }
        val socket = FakeDevice(first.deviceId, newAccess)
        socket.connect(http)
        assertEquals("E_AUTH", socket.expect("error").bodyString("code"))
    }

    @Test
    fun `an expired access token is E_AUTH on the socket`() = testApplication {
        application { module(config()) }
        val first = claimOnce(client)
        auth.deviceFor(first.access)
        clock.addAndGet(16 * 60 * 1000)
        auth.revoke(first.deviceId)

        val http = createClient { install(WebSockets) }
        val socket = FakeDevice(first.deviceId, first.access)
        socket.connect(http)
        assertEquals("E_AUTH", socket.expect("error").bodyString("code"))
    }
}
