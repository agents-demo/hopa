package com.hopa.backend.protocol

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private data class FixtureCase(
    val name: String,
    val accepted: Boolean,
    val message: String,
)

class GatewayCodecTest {
    private fun cases(): List<FixtureCase> {
        val raw = requireNotNull(javaClass.getResource("/fixtures/gateway-v0.json")) {
            "fixtures are not on the test classpath"
        }.readText()
        return Json.parseToJsonElement(raw).jsonObject["cases"]!!.jsonArray.map { element ->
            val case = element.jsonObject
            FixtureCase(
                name = case["name"]!!.jsonPrimitive.content,
                accepted = case["ok"]!!.jsonPrimitive.boolean,
                message = case["message"]!!.jsonObject.toString(),
            )
        }
    }

    @Test
    fun `every accepted fixture decodes and re-decodes identically`() {
        val accepted = cases().filter { it.accepted }
        assertTrue("expected at least ten accepted vectors", accepted.size >= 10)

        for (case in accepted) {
            val first = GatewayCodec.decode(case.message)
            assertTrue(case.name, first is DecodeResult.Ok)

            val envelope = (first as DecodeResult.Ok).envelope
            assertTrue(case.name, envelope.id.isNotEmpty())

            val again = GatewayCodec.decode(GatewayCodec.encode(envelope))
            assertEquals(case.name, envelope, (again as DecodeResult.Ok).envelope)
        }
    }

    @Test
    fun `a malformed message is a schema failure, not an exception`() {
        val result = GatewayCodec.decode("{not json")

        assertTrue(result is DecodeResult.Failed)
        assertEquals("E_SCHEMA", (result as DecodeResult.Failed).error.code)
    }

    @Test
    fun `unknown fields are dropped on re-encode`() {
        val raw = """
            {"v":1,"id":"018f3a5e-6b1c-7c3a-9d2e-4f5a6b7c8d9e","type":"task.create",
             "ts":1,"to":"dev-1","household":"hh_evil","body":{}}
        """.trimIndent()

        val envelope = (GatewayCodec.decode(raw) as DecodeResult.Ok).envelope

        assertFalse(GatewayCodec.encode(envelope).contains("household"))
        assertEquals("dev-1", envelope.to)
    }
}
