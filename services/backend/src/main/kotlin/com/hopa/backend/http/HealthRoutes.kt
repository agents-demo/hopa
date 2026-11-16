package com.hopa.backend.http

import com.hopa.backend.ServerConfig
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.request.header
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
    val queueDepth: Int? = null,
)

@Serializable
data class VersionResponse(
    val version: String,
    val protocol: Int = 1,
)

fun Application.healthRoutes(config: ServerConfig) {
    routing {
        get("/v1/health") {
            val token = call.request.header(HttpHeaders.Authorization)
                ?.removePrefix("Bearer ")
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
            val identity = token?.let(config.auth::deviceFor)
            val queueDepth = identity?.let { config.db.queueDepth(it.householdId) }
            val db = config.db.status()
            // A deploy gate reads this: a reachable process with an unreachable
            // database is not healthy, so it must not answer 200.
            val status = if (db == "down") HttpStatusCode.ServiceUnavailable else HttpStatusCode.OK
            call.respond(
                status,
                HealthResponse(
                    ok = db != "down",
                    version = config.version,
                    db = db,
                    queueDepth = queueDepth,
                ),
            )
        }
        get("/v1/version") {
            call.respond(VersionResponse(version = config.version))
        }
    }
}
