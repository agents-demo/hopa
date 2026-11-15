package com.hopa.backend

import com.hopa.backend.gateway.gatewayRoutes
import com.hopa.backend.http.healthRoutes
import com.hopa.backend.pairing.PairingService
import com.hopa.backend.pairing.pairingRoutes
import com.hopa.backend.store.Database
import com.hopa.backend.store.PostgresProbe
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import kotlinx.serialization.json.Json

fun Application.module(config: ServerConfig) {
    install(ContentNegotiation) {
        json(Json { explicitNulls = false; encodeDefaults = true })
    }
    healthRoutes(config)
    pairingRoutes(config)
    gatewayRoutes(config)
}

fun main() {
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    val version = System.getenv("HOPA_VERSION") ?: "0.1.0"

    // Migrations finish before the listener opens: a container that cannot
    // migrate must fail its health check, not serve against half a schema.
    val database = Database.fromEnvironment()
    database?.migrate()

    val config = ServerConfig(
        version = version,
        db = database?.let(::PostgresProbe) ?: com.hopa.backend.store.DbProbe.Unconfigured,
        pairing = database?.let(::PairingService),
        bootstrapToken = System.getenv("HOPA_BOOTSTRAP_TOKEN"),
    )

    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        module(config)
    }.start(wait = true)
}
