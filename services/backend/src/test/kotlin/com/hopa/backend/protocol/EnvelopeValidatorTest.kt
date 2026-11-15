package com.hopa.backend.protocol

import java.util.UUID
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EnvelopeValidatorTest {
    private fun envelope() = Envelope(
        v = 1,
        id = UUID.randomUUID().toString(),
        type = "task.create",
        ts = 1,
        to = "dev-pc",
        body = JsonObject(emptyMap()),
    )

    @Test
    fun `a frame over the cap is refused`() {
        val envelope = envelope()
        val raw = GatewayCodec.encode(
            envelope.copy(body = JsonObject(mapOf("blob" to kotlinx.serialization.json.JsonPrimitive("a".repeat(70_000))))),
        )

        val error = EnvelopeValidator.validate(raw, envelope)

        assertEquals("E_SCHEMA", error?.code)
    }

    @Test
    fun `an unknown major version is refused`() {
        val envelope = envelope().copy(v = 2)

        val error = EnvelopeValidator.validate(GatewayCodec.encode(envelope), envelope)

        assertEquals("E_VERSION", error?.code)
    }

    @Test
    fun `an unknown type is refused`() {
        val envelope = envelope().copy(type = "device.reboot")

        val error = EnvelopeValidator.validate(GatewayCodec.encode(envelope), envelope)

        assertEquals("E_UNSUPPORTED", error?.code)
    }

    @Test
    fun `a blank id is refused`() {
        val envelope = envelope().copy(id = " ")

        val error = EnvelopeValidator.validate(GatewayCodec.encode(envelope), envelope)

        assertEquals("E_SCHEMA", error?.code)
    }

    @Test
    fun `an invalid trace is replaced, not rejected`() {
        val envelope = envelope().copy(trace = "not-a-traceparent")

        assertNull(EnvelopeValidator.validate(GatewayCodec.encode(envelope), envelope))
        assertTrue(
            EnvelopeValidator.traceOf(envelope)
                .matches(Regex("^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")),
        )
    }

    @Test
    fun `a valid trace is preserved`() {
        val trace = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"

        assertEquals(trace, EnvelopeValidator.traceOf(envelope().copy(trace = trace)))
    }

    @Test
    fun `a task message without a target is refused`() {
        val envelope = envelope().copy(to = null)

        val error = EnvelopeValidator.validate(GatewayCodec.encode(envelope), envelope)

        assertEquals("E_SCHEMA", error?.code)
    }

    @Test
    fun `a non-uuid id is refused`() {
        val envelope = envelope().copy(id = "x")

        val error = EnvelopeValidator.validate(GatewayCodec.encode(envelope), envelope)

        assertEquals("E_SCHEMA", error?.code)
    }

    @Test
    fun `every schema-invalid fixture names the validator code`() {
        val raw = requireNotNull(javaClass.getResource("/fixtures/gateway-v0.json")).readText()
        val cases = Json.parseToJsonElement(raw).jsonObject["cases"]!!.jsonArray
        var checked = 0
        for (element in cases) {
            val case = element.jsonObject
            val schemaValid = case["schema"]?.jsonPrimitive?.boolean
                ?: case["ok"]!!.jsonPrimitive.boolean
            val expected = case["error"]?.jsonPrimitive?.content
            if (schemaValid ||
                expected == null ||
                expected !in setOf("E_SCHEMA", "E_VERSION", "E_UNSUPPORTED")
            ) {
                continue
            }
            checked++
            val message = case["message"]!!.jsonObject.toString()
            val actual = when (val decoded = GatewayCodec.decode(message)) {
                is DecodeResult.Failed -> decoded.error.code
                is DecodeResult.Ok -> EnvelopeValidator.validate(message, decoded.envelope)?.code
            }
            assertEquals(case["name"]!!.jsonPrimitive.content, expected, actual)
        }
        assertTrue("expected at least four validator-level fixtures", checked >= 4)
    }
}
