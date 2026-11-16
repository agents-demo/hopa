package com.hopa.backend.pairing

import com.hopa.backend.ServerConfig
import com.hopa.backend.http.BodyTooLarge
import com.hopa.backend.http.receiveBounded
import com.hopa.backend.http.respondError
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.response.respond
import io.ktor.server.routing.post
import io.ktor.server.routing.routing
import kotlinx.serialization.Serializable

@Serializable
data class RefreshRequest(val refreshToken: String)

@Serializable
data class RefreshResponse(
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: String,
)

fun Application.tokenRoutes(config: ServerConfig) {
    val issuer = config.tokenIssuer ?: return

    routing {
        post("/v1/token/refresh") {
            val request = try {
                call.receiveBounded(RefreshRequest.serializer())
            } catch (_: BodyTooLarge) {
                call.respondError(
                    HttpStatusCode.PayloadTooLarge,
                    "E_SCHEMA",
                    "request body is larger than 64 KiB",
                )
                return@post
            } catch (_: Exception) {
                call.respondError(HttpStatusCode.BadRequest, "E_SCHEMA", "invalid JSON body")
                return@post
            }
            when (val outcome = issuer.rotate(request.refreshToken)) {
                is RotateOutcome.Rotated -> call.respond(
                    HttpStatusCode.OK,
                    RefreshResponse(
                        accessToken = outcome.access.token,
                        refreshToken = outcome.refresh.token,
                        expiresAt = outcome.access.expiresAt,
                    ),
                )

                RotateOutcome.Refused -> call.respondError(
                    HttpStatusCode.Unauthorized,
                    "E_AUTH",
                    "refresh token is not valid",
                )
            }
        }
    }
}
