package com.hopa.backend

import com.hopa.backend.http.healthRoutes
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation

fun Application.module(config: ServerConfig) {
    install(ContentNegotiation) {
        json()
    }
    healthRoutes(config)
}

fun main() {
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    val version = System.getenv("HOPA_VERSION") ?: "0.1.0"

    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        module(ServerConfig(version = version))
    }.start(wait = true)
}
