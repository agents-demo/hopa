package com.hopa.backend.http

import com.hopa.backend.ServerConfig
import com.hopa.backend.module
import com.hopa.backend.store.DbProbe
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

class HealthTest {
    @Test
    fun `health reports ok and the build version`() = testApplication {
        application { module(ServerConfig(version = "0.1.0")) }

        val response = client.get("/v1/health")

        assertEquals(HttpStatusCode.OK, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        assertEquals(true, body["ok"]!!.jsonPrimitive.boolean)
        assertEquals("0.1.0", body["version"]!!.jsonPrimitive.content)
        assertEquals("unconfigured", body["db"]!!.jsonPrimitive.content)
    }

    @Test
    fun `health is 503 and not ok when the database is down`() = testApplication {
        application { module(ServerConfig(version = "0.1.0", db = DbProbe { "down" })) }

        val response = client.get("/v1/health")

        assertEquals(HttpStatusCode.ServiceUnavailable, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        assertEquals(false, body["ok"]!!.jsonPrimitive.boolean)
        assertEquals("down", body["db"]!!.jsonPrimitive.content)
    }

    @Test
    fun `version reports protocol 1`() = testApplication {
        application { module(ServerConfig(version = "9.9.9")) }

        val body = Json.parseToJsonElement(
            client.get("/v1/version").bodyAsText(),
        ).jsonObject

        assertEquals(1, body["protocol"]!!.jsonPrimitive.int)
        assertEquals("9.9.9", body["version"]!!.jsonPrimitive.content)
    }
}
