package com.hopa.backend.log

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class JsonLogTest {
    @Test
    fun `a refusal logs identifiers but never the token or the body`() {
        val lines = mutableListOf<String>()
        val log = JsonEventLog(out = { lines += it }, clock = { 1_763_212_800_000 })

        log.event(
            "tenant_refused",
            mapOf(
                "trace_id" to "a".repeat(32),
                "household_id" to "hh-1",
                "device_id" to "dev-a",
                "to" to "dev-b",
                "token" to "SECRET-TOKEN",
                "body" to "find the lease",
            ),
        )

        val line = lines.single()
        val json = Json.parseToJsonElement(line).jsonObject
        assertEquals("tenant_refused", json["event"]!!.jsonPrimitive.content)
        assertEquals("a".repeat(32), json["trace_id"]!!.jsonPrimitive.content)
        assertEquals("hh-1", json["household_id"]!!.jsonPrimitive.content)
        assertFalse(line.contains("SECRET-TOKEN"))
        assertFalse(line.contains("find the lease"))
    }
}
