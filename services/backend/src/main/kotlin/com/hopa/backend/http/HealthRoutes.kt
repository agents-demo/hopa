package com.hopa.backend.http

import com.hopa.backend.ServerConfig
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.response.respond
import io.ktor.server.routing.get
import io.ktor.server.routing.routing
import kotlinx.serialization.Serializable

/** Liveness plus the database state a deploy gates on. */
@Serializable
data class HealthResponse(
    val ok: Boolean,
    val version: String,
    val db: String,
)

@Serializable
data class VersionResponse(
    val version: String,
    val protocol: Int = 1,
)

fun Application.healthRoutes(config: ServerConfig) {
    routing {
        get("/v1/health") {
            call.respond(
                HealthResponse(ok = true, version = config.version, db = "unconfigured"),
            )
        }
        get("/v1/version") {
            call.respond(VersionResponse(version = config.version))
        }
    }
}
