package com.hopa.sidecar.backend

import com.hopa.backend.link.BackendClient
import com.hopa.backend.link.BackendLink
import com.hopa.backend.pairing.BackendCredentials
import com.hopa.backend.pairing.BackendPairing
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.protocol.Stdio
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Builds and starts the gateway from a stored session.
 *
 * Both the boot path and the `backend.pair` command go through this one helper,
 * so refresh, diag state and the turn adapter cannot drift between them.
 */
internal class GatewayHost(
    private val io: Stdio,
    private val store: ChatStore,
    private val records: RecordStore,
    private val sessionStore: BackendSessionStore,
    private val runner: EngineTaskRunner,
    private val scope: CoroutineScope,
) {
    private var current: CoroutineScope? = null

    @Synchronized
    fun start(session: BackendSession, contentKey: ByteArray) {
        require(contentKey.size == CONTENT_KEY_BYTES) { "content key must be $CONTENT_KEY_BYTES bytes" }
        current?.cancel()
        var credentials = BackendCredentials(
            deviceId = session.deviceId,
            householdId = session.householdId,
            accessToken = session.accessToken,
            refreshToken = session.refreshToken,
            expiresAt = session.expiresAt,
            gatewayUrl = session.gatewayUrl,
        )
        val pairing = BackendPairing(session.gatewayUrl)
        val link: BackendLink = BackendClient(
            credentials = { credentials },
            pushToken = { null },
            refresh = {
                // A refresh rotates the token pair but not the identity, so the
                // stored device and household are copied back in. An unreachable
                // backend is left as a throw for the client's own backoff; only
                // a successful rotation is persisted.
                val refreshed = pairing.refresh(credentials.refreshToken)
                credentials = refreshed.copy(
                    deviceId = session.deviceId,
                    householdId = session.householdId,
                    gatewayUrl = session.gatewayUrl,
                )
                runCatching {
                    sessionStore.save(
                        session.copy(
                            accessToken = refreshed.accessToken,
                            refreshToken = refreshed.refreshToken,
                            expiresAt = refreshed.expiresAt,
                        ),
                    )
                }.onFailure { failed ->
                    io.log(
                        "backend session could not be saved (${failed.javaClass.simpleName}); " +
                            "reconnecting with memory only",
                    )
                }
                credentials
            },
            deviceName = "Windows PC",
            appVersion = Protocol.VERSION.toString(),
        )
        val gateway = BackendGateway(
            link = link,
            contentKey = contentKey,
            run = runner::run,
            onDiagState = {
                buildJsonObject {
                    put("appVersion", Protocol.VERSION.toString())
                    put("conversations", store.list(includeArchived = true).size)
                    put("runs", records.count())
                }
            },
        )
        // A fresh supervisor per start: stopping one gateway must not cancel the
        // scope the next one runs in.
        val live = CoroutineScope(scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job]))
        current = live
        live.launch { gateway.runForever(live) }
    }
}
