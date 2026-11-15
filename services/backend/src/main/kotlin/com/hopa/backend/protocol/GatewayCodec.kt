package com.hopa.backend.protocol

import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * The wire codec. Decoding never throws: a broken frame is a value the caller
 * can answer with an error, because a device that sends garbage still deserves
 * a well-formed refusal.
 */
object GatewayCodec {
    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        encodeDefaults = false
    }

    fun decode(raw: String): DecodeResult =
        try {
            DecodeResult.Ok(json.decodeFromString(Envelope.serializer(), raw))
        } catch (_: SerializationException) {
            DecodeResult.Failed(GatewayError("E_SCHEMA", "invalid envelope"))
        } catch (_: IllegalArgumentException) {
            DecodeResult.Failed(GatewayError("E_SCHEMA", "invalid envelope"))
        }

    fun encode(envelope: Envelope): String =
        json.encodeToString(Envelope.serializer(), envelope)
}
