package com.hopa.backend.trace

import com.hopa.backend.ServerConfig
import com.hopa.backend.http.respondError
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.request.header
import io.ktor.server.response.respond
import io.ktor.server.routing.get
import io.ktor.server.routing.routing
import kotlinx.serialization.Serializable

@Serializable
data class TraceResponse(val traceId: String, val spans: List<SpanView>)

fun Application.traceRoutes(config: ServerConfig) {
    val query = config.traceQuery ?: return

    routing {
        get("/v1/traces/{traceId}") {
            val token = call.request.header(HttpHeaders.Authorization)
                ?.removePrefix("Bearer ")
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
            val identity = token?.let(config.auth::deviceFor)
            if (identity == null) {
                call.respondError(HttpStatusCode.Unauthorized, "E_AUTH", "unknown or expired token")
                return@get
            }

            val traceId = call.parameters["traceId"].orEmpty()
            if (!TraceIds.valid(traceId)) {
                call.respondError(HttpStatusCode.NotFound, "E_TENANT", "unknown trace")
                return@get
            }

            val spans = query.spans(identity.householdId, traceId)
            if (spans.isEmpty()) {
                // The same answer as another household's trace: existence is not
                // something a caller may probe.
                call.respondError(HttpStatusCode.NotFound, "E_TENANT", "unknown trace")
                return@get
            }
            call.respond(TraceResponse(traceId, spans))
        }
    }
}
