package com.hopa.backend.pairing

import com.hopa.backend.ServerConfig
import com.hopa.backend.http.respondError
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.ApplicationCall
import io.ktor.server.application.call
import io.ktor.server.request.header
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.post
import io.ktor.server.routing.routing
import java.security.MessageDigest

fun Application.pairingRoutes(config: ServerConfig) {
    val api = config.pairing ?: return
    val bootstrap = config.bootstrapToken

    routing {
        post("/v1/pair/sessions") {
            val presented = call.request.header(HttpHeaders.Authorization)
                ?.removePrefix("Bearer ")
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
            if (bootstrap == null || presented == null || !constantTimeEquals(presented, bootstrap)) {
                call.respondError(HttpStatusCode.Unauthorized, "E_AUTH", "bad bootstrap token")
                return@post
            }
            val request = try {
                call.receive<MintRequest>()
            } catch (_: Exception) {
                call.respondError(HttpStatusCode.BadRequest, "E_SCHEMA", "invalid JSON body")
                return@post
            }
            when (val outcome = api.mint(
                request.householdName,
                request.memberName,
                remoteAddress(call),
                request.householdId,
            )) {
                is PairingOutcome.Ok -> call.respond(HttpStatusCode.Created, outcome.value)
                is PairingOutcome.Refused -> call.refuse(outcome)
            }
        }

        post("/v1/pair/claim") {
            val request = try {
                call.receive<ClaimRequest>()
            } catch (_: Exception) {
                call.respondError(HttpStatusCode.BadRequest, "E_SCHEMA", "invalid JSON body")
                return@post
            }
            when (val outcome = api.claim(request, remoteAddress(call))) {
                is PairingOutcome.Ok -> call.respond(HttpStatusCode.Created, outcome.value)
                is PairingOutcome.Refused -> call.refuse(outcome)
            }
        }
    }
}

private suspend fun ApplicationCall.refuse(refusal: PairingOutcome.Refused) {
    val status = when (refusal.code) {
        "E_AUTH" -> HttpStatusCode.Unauthorized
        "E_RATE" -> HttpStatusCode.TooManyRequests
        else -> HttpStatusCode.BadRequest
    }
    respondError(status, refusal.code, refusal.message, refusal.retryable)
}

/** The first proxy hop is the client address; Render sets X-Forwarded-For. */
private fun remoteAddress(call: ApplicationCall): String =
    call.request.header("X-Forwarded-For")
        ?.substringBefore(",")
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?: call.request.local.remoteHost

private fun constantTimeEquals(a: String, b: String): Boolean =
    MessageDigest.isEqual(a.toByteArray(Charsets.UTF_8), b.toByteArray(Charsets.UTF_8))
