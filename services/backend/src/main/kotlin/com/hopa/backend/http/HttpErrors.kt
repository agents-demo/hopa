package com.hopa.backend.http

import io.ktor.http.HttpStatusCode
import io.ktor.server.application.ApplicationCall
import io.ktor.server.response.respond
import java.util.UUID
import kotlinx.serialization.Serializable

/** The error shape every `/v1` route returns, and the gateway's `error` body. */
@Serializable
data class HttpError(
    val code: String,
    val message: String,
    val retryable: Boolean = false,
    val traceId: String,
)

fun newTraceId(): String = UUID.randomUUID().toString().replace("-", "")

suspend fun ApplicationCall.respondError(
    status: HttpStatusCode,
    code: String,
    message: String,
    retryable: Boolean = false,
) {
    respond(status, HttpError(code = code, message = message, retryable = retryable, traceId = newTraceId()))
}
