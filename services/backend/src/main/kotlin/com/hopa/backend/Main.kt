package com.hopa.backend

import com.hopa.backend.auth.AuthPort
import com.hopa.backend.gateway.gatewayRoutes
import com.hopa.backend.http.healthRoutes
import com.hopa.backend.log.JsonEventLog
import com.hopa.backend.pairing.PairingService
import com.hopa.backend.pairing.PgAuth
import com.hopa.backend.pairing.TokenIssuer
import com.hopa.backend.pairing.pairingRoutes
import com.hopa.backend.pairing.tokenRoutes
import com.hopa.backend.push.FcmSender
import com.hopa.backend.push.GuardedPush
import com.hopa.backend.push.PushPort
import com.hopa.backend.push.ServiceAccountFcmAuth
import com.hopa.backend.store.Database
import com.hopa.backend.store.DbProbe
import com.hopa.backend.store.PgDevices
import com.hopa.backend.store.PgTaskStore
import com.hopa.backend.store.PostgresProbe
import com.hopa.backend.tasks.DeviceDirectory
import com.hopa.backend.tasks.InMemoryTaskStore
import com.hopa.backend.tasks.TaskStore
import com.hopa.backend.trace.PgTraceStore
import com.hopa.backend.trace.TraceRecorder
import com.hopa.backend.trace.traceRoutes
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
    tokenRoutes(config)
    traceRoutes(config)
    gatewayRoutes(config)
}

fun main() {
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    val version = System.getenv("HOPA_VERSION") ?: "0.1.0"

    // Migrations finish before the listener opens: a container that cannot
    // migrate must fail its health check, not serve against half a schema.
    val database = Database.fromEnvironment()
    database?.migrate()

    val auth: PgAuth? = database?.let(::PgAuth)
    val devices: DeviceDirectory = database?.let(::PgDevices) ?: DeviceDirectory.Empty
    val tokens = database?.let { db ->
        TokenIssuer(db, onRevoke = { deviceId -> auth?.revoke(deviceId) })
    }

    val fcmProject = System.getenv("HOPA_FCM_PROJECT")
    val fcmCredentials = System.getenv("HOPA_FCM_CREDENTIALS")
    val push: PushPort = if (fcmProject != null && fcmCredentials != null) {
        GuardedPush(
            FcmSender(
                projectId = fcmProject,
                auth = ServiceAccountFcmAuth(fcmCredentials),
            ),
        )
    } else {
        PushPort.None
    }

    val traceStore = database?.let { PgTraceStore(it) }

    val config = ServerConfig(
        version = version,
        auth = auth ?: AuthPort.DenyAll,
        devices = devices,
        db = database?.let(::PostgresProbe) ?: DbProbe.Unconfigured,
        pairing = if (database != null && tokens != null) {
            PairingService(database, tokens = tokens)
        } else {
            null
        },
        bootstrapToken = System.getenv("HOPA_BOOTSTRAP_TOKEN"),
        tokenIssuer = tokens,
        tasks = database?.let { PgTaskStore(it) } ?: InMemoryTaskStore(),
        push = push,
        traces = traceStore ?: TraceRecorder.None,
        traceQuery = traceStore,
        log = JsonEventLog(),
    )

    embeddedServer(Netty, port = port, host = "0.0.0.0") {
        module(config)
    }.start(wait = true)
}
