package com.hopa.backend.protocol

import java.security.SecureRandom

/**
 * Protocol v0 rules that are not expressible in JSON Schema, or that must hold
 * even when the schema is bypassed by a hand-built frame.
 *
 * Order matters: the cheapest refusal wins, so an oversized frame never reaches
 * the decoder.
 */
object EnvelopeValidator {
    const val MAX_FRAME_BYTES = 65_536

    val TYPES: Set<String> = setOf(
        "device.hello",
        "device.hello.ack",
        "presence",
        "task.create",
        "task.ack",
        "task.progress",
        "task.result",
        "task.error",
        "task.cancel",
        "error",
        "ping",
        "pong",
    )

    private val TRACEPARENT = Regex("^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")
    private val MESSAGE_ID =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private val random = SecureRandom()

    fun validate(raw: String, envelope: Envelope): GatewayError? = when {
        raw.toByteArray(Charsets.UTF_8).size > MAX_FRAME_BYTES ->
            GatewayError("E_SCHEMA", "frame is larger than $MAX_FRAME_BYTES bytes")

        envelope.v != 1 ->
            GatewayError("E_VERSION", "unsupported protocol version ${envelope.v}")

        envelope.type !in TYPES ->
            GatewayError("E_UNSUPPORTED", "unsupported message type")

        envelope.ts < 0 ->
            GatewayError("E_SCHEMA", "negative timestamp")

        !MESSAGE_ID.matches(envelope.id) ->
            GatewayError("E_SCHEMA", "message id is not a UUID")

        envelope.from?.isBlank() == true ||
            envelope.to?.isBlank() == true ||
            envelope.task?.isBlank() == true ->
            GatewayError("E_SCHEMA", "blank device or task id")

        envelope.type.startsWith("task.") && envelope.to == null ->
            GatewayError("E_SCHEMA", "a task message needs a target device")

        else -> null
    }

    /**
     * A valid traceparent is kept so a client's chain survives the hop; anything
     * else is replaced rather than refused, because a bad trace must not cost a
     * task.
     */
    fun traceOf(envelope: Envelope): String {
        val trace = envelope.trace
        if (trace != null && TRACEPARENT.matches(trace)) {
            return trace
        }
        return "00-${hex(16)}-${hex(8)}-01"
    }

    private fun hex(bytes: Int): String {
        val buffer = ByteArray(bytes)
        random.nextBytes(buffer)
        return buffer.joinToString("") { "%02x".format(it) }
    }
}
