package com.hopa.backend.protocol

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * One frame on the gateway WebSocket, and the same shape in a queue row.
 *
 * There is deliberately no `household` field: identity comes from the access
 * token, so a client cannot name another household even by adding the field.
 * Unknown fields are ignored by the codec and never re-emitted.
 */
@Serializable
data class Envelope(
    val v: Int,
    val id: String,
    val type: String,
    val ts: Long,
    val trace: String? = null,
    @SerialName("from") val from: String? = null,
    val to: String? = null,
    val task: String? = null,
    val body: JsonObject = JsonObject(emptyMap()),
)

/** A stable, user-facing failure. The UI never parses the message text. */
data class GatewayError(
    val code: String,
    val message: String,
    val retryable: Boolean = false,
)

sealed interface DecodeResult {
    data class Ok(val envelope: Envelope) : DecodeResult

    data class Failed(val error: GatewayError) : DecodeResult
}
