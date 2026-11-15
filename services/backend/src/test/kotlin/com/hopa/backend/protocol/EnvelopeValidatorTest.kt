package com.hopa.backend.protocol

import java.util.UUID
import kotlinx.serialization.json.JsonObject
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
}
