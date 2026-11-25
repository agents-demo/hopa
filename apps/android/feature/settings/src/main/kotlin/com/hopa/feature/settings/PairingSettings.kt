package com.hopa.feature.settings

import com.hopa.bridge.session.BridgeClient
import com.hopa.capabilities.display.client.HelperStatus
import com.hopa.stores.AppSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

/**
 * Pairing, in both directions: the gateway that delivers tasks and the bridge
 * that drives a computer. Each call returns the one line the card should show,
 * so the ViewModel only copies it into its state.
 */
internal class PairingSettings(
    private val deps: PairingDependencies,
) {
    suspend fun snapshot(settings: AppSettings): PairingSnapshot = PairingSnapshot(
        backendUrl = settings.backendUrl,
        backendDeviceId = settings.backendDeviceId,
        backendName = deps.backendName(),
        approvalKeyFingerprint = if (settings.backendDeviceId.isBlank()) "" else deps.approvalKeyFingerprint(),
        backendToken = deps.backendToken(),
        fcmAvailable = deps.fcmAvailable(),
        bridgeKey = deps.settings.bridgeToken(),
    )

    /**
     * Pair the gateway. The field takes the whole `hopa://pair…` link or a bare
     * session next to the address on screen; nothing is guessed when both are
     * missing.
     */
    suspend fun pair(url: String, text: String): String {
        val link = PairInput.normalise(text, url.trim())
            ?: return "Couldn't pair: paste a link or an address from your computer"
        return deps.pairGateway(link)
    }

    /** Close the socket but keep the stored identity, so the next open reconnects. */
    suspend fun disconnectBackend(): String {
        return deps.disconnectGateway()
    }

    suspend fun pairBridge(url: String, code: String): String {
        if (url.isBlank() || code.isBlank()) {
            return "Bridge: address and pair code first"
        }
        return runCatching {
            val session = BridgeClient(url, "").pair(code.trim())
            deps.settings.setBridgeToken(session.token)
            deps.settings.setBridgeRefresh(session.refresh)
            "Bridge paired; the token is in the Keystore"
        }.getOrElse { error -> "Bridge: ${error.message}" }
    }

    suspend fun testBridge(url: String, token: String): String {
        if (url.isBlank()) {
            return "Bridge: set an address first"
        }
        val effective = token.ifBlank {
            runCatching { deps.settings.bridgeToken() }.getOrDefault("")
        }
        return runCatching {
            val client = BridgeClient(url, effective)
            client.health()
            val who = client.whoami()
            val devices = who["devices"]?.jsonArray
                ?.joinToString { it.jsonPrimitive.content }
            val nodes = client.observe()["nodes"]?.jsonArray?.size ?: 0
            "Bridge ok: ${devices ?: "paired"}, $nodes nodes"
        }.getOrElse { error -> "Bridge: ${error.message}" }
    }

    /** Pair with this phone's own adbd; no PC needed after this succeeds. */
    suspend fun pairWireless(address: String, code: String): String =
        deps.pairWireless(address, code)

    /** Read the code from Android's pairing dialog instead of asking for it. */
    fun pairWirelessFromScreen() {
        deps.pairWirelessFromScreen()
    }

    /** Wait for a dialog the person opens, then read its code and pair. */
    fun pairWirelessWaiting() {
        deps.pairWirelessWaiting()
    }

    /** Start the hidden-screen helper on the phone, using the paired PC bridge. */
    suspend fun startBackgroundHelper(): String {
        val current = deps.settings.settings.first()
        val token = deps.settings.bridgeToken()
        return when {
            current.bridgeUrl.isBlank() -> "Bridge: set an address first"
            token.isBlank() -> "Bridge: pair first, then start the helper"
            else -> when (val status = withContext(Dispatchers.IO) { deps.helper.ensure() }) {
                is HelperStatus.Running -> "Hidden screen is ready"
                is HelperStatus.Failed -> "Hidden screen: ${status.reason}"
                else -> "Hidden screen: not started"
            }
        }
    }
}
