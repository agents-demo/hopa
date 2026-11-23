package com.hopa.sidecar.protocol.handlers

import com.hopa.sidecar.backend.BackendPairing
import com.hopa.sidecar.backend.BackendSessionStore
import com.hopa.sidecar.backend.GatewayHost
import com.hopa.sidecar.backend.backendContentKey
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import java.nio.file.Path
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject

/**
 * Pairing this PC with the gateway.
 *
 * It polls and prints the QR on stderr, so it runs on its own scope and never
 * blocks the stdin loop; the reply carries identifiers only.
 */
internal class BackendHandler(
    private val io: Stdio,
    private val dataDir: Path,
    private val sessionStore: BackendSessionStore,
    private val gateways: GatewayHost,
    private val scope: CoroutineScope,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (type != "backend.pair") return false
        val url = message.text("url").trim()
        val name = message.text("name").trim().ifBlank { "Windows PC" }
        scope.launch {
            val reply = if (url.isBlank()) {
                Protocol.backendPair(ok = false, error = "IllegalArgumentException")
            } else {
                try {
                    BackendPairing(dataDir).admit(url, name)
                    val saved = sessionStore.load()
                        ?: throw IllegalStateException("admission did not store a session")
                    val key = backendContentKey(saved)
                        ?: throw IllegalStateException("admission stored an invalid content key")
                    gateways.start(saved, key)
                    Protocol.backendPair(ok = true)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failed: Exception) {
                    io.log("backend pairing failed (${failed.javaClass.simpleName})")
                    Protocol.backendPair(ok = false, error = failed.javaClass.simpleName)
                }
            }
            io.send(reply)
        }
        return true
    }
}
