package com.hopa.backend.http

import io.ktor.server.application.ApplicationCall
import io.ktor.server.request.contentLength
import io.ktor.server.request.receiveChannel
import io.ktor.utils.io.readRemaining
import kotlinx.io.readByteArray
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json

/** The HTTP surface shares the gateway's 64 KiB cap; a bigger body is refused, not buffered. */
const val MAX_HTTP_BODY_BYTES = 65_536

class BodyTooLarge : RuntimeException()

private val httpJson = Json { ignoreUnknownKeys = true }

/**
 * Reads a JSON body with a hard cap. `Content-Length` is checked first so a
 * declared oversize body costs nothing; the bounded read covers a chunked body
 * that declares nothing.
 */
suspend fun <T> ApplicationCall.receiveBounded(
    serializer: KSerializer<T>,
    maxBytes: Int = MAX_HTTP_BODY_BYTES,
): T {
    val declared = request.contentLength()
    if (declared != null && declared > maxBytes) throw BodyTooLarge()
    val packet = receiveChannel().readRemaining(maxBytes.toLong() + 1)
    val bytes = packet.readByteArray()
    if (bytes.size > maxBytes) throw BodyTooLarge()
    return httpJson.decodeFromString(serializer, bytes.decodeToString())
}
