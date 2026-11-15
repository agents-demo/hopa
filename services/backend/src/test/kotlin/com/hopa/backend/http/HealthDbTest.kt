package com.hopa.backend.http

import com.hopa.backend.ServerConfig
import com.hopa.backend.harness.PostgresHarness
import com.hopa.backend.module
import com.hopa.backend.store.PostgresProbe
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HealthDbTest {
    @Test
    fun `health reports ok when postgres answers`() = testApplication {
        val db = PostgresHarness.appDatabase()
        application { module(ServerConfig(version = "0.1.0", db = PostgresProbe(db))) }

        val body = Json.parseToJsonElement(client.get("/v1/health").bodyAsText()).jsonObject

        assertEquals("ok", body["db"]!!.jsonPrimitive.content)
        assertNull(body["queueDepth"])
    }
}
