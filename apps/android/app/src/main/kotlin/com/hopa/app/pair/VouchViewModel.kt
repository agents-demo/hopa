package com.hopa.app.pair

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.backend.crypto.KeyWrap
import com.hopa.backend.pairing.AdmissionLink
import com.hopa.backend.pairing.BackendPairing
import com.hopa.backend.pairing.BackendPairingFailure
import com.hopa.feature.settings.PairInput
import com.hopa.stores.SettingsRepository
import java.util.Base64
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Vouch for a pending PC by wrapping this phone's household content key for the
 * PC's X25519 key and posting the wrap. The session secret lives only in the
 * scanned QR; the content key, private key and access token are read from the
 * secret store and never appear in a message or a log line.
 */
class VouchViewModel(
    private val settings: SettingsRepository,
    private val pairing: (String) -> BackendPairing = { BackendPairing(it) },
) : ViewModel() {
    private val _state = MutableStateFlow(VouchUiState())
    val state: StateFlow<VouchUiState> = _state.asStateFlow()

    /** The session being vouched for, held between resolve and confirm. */
    private var session: PendingSession? = null

    /** A scanned QR: resolve the pending session named by its secret. */
    fun resolve(link: AdmissionLink) {
        viewModelScope.launch { resolveInternal(link.session, link.gatewayUrl) }
    }

    /** A pasted code: parse the admission link, then enter the same state. */
    fun resolvePasted(text: String) {
        val link = PairInput.admission(text)
        if (link == null) {
            _state.update { it.copy(error = NOT_A_CODE) }
            return
        }
        resolve(link)
    }

    /** Wrap the content key for the PC and post the vouch. */
    fun confirm() {
        val current = session ?: return
        viewModelScope.launch {
            _state.update { it.copy(busy = true, error = null) }
            val contentKey = settings.backendContentKey()
            if (contentKey.isBlank()) {
                _state.update { it.copy(busy = false, confirm = null, error = NO_HOUSEHOLD_KEY) }
                return@launch
            }
            try {
                val contentKeyBytes = Base64.getDecoder().decode(contentKey)
                val privateKeyBytes = Base64.getDecoder().decode(settings.backendPrivateKey())
                val pcPublicKeyBytes = Base64.getUrlDecoder().decode(current.publicKey)
                val wrapped = KeyWrap.wrapForDevice(contentKeyBytes, pcPublicKeyBytes, privateKeyBytes)
                val wrappedKey = Base64.getUrlEncoder().withoutPadding().encodeToString(wrapped)
                pairing(current.gatewayUrl).vouch(
                    sessionSecret = current.secret,
                    wrappedKey = wrappedKey,
                    accessToken = settings.backendAccessToken(),
                )
                _state.update { it.copy(busy = false, vouched = true) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (refused: BackendPairingFailure.Refused) {
                _state.update { it.copy(busy = false, error = refusedCode(refused)) }
            } catch (unavailable: BackendPairingFailure.Unavailable) {
                _state.update { it.copy(busy = false, error = unavailable.message) }
            } catch (error: Exception) {
                _state.update { it.copy(busy = false, error = COULD_NOT_VOUCH) }
            }
        }
    }

    private suspend fun resolveInternal(secret: String, gatewayUrl: String) {
        _state.update { it.copy(busy = true, error = null) }
        try {
            val pending = pairing(gatewayUrl).pollPending(secret)
            if (pending.state != "pending") {
                // The server reports expired/claimed/vouched as a 200 with a state,
                // so refuse here instead of asking the phone to vouch for a session
                // that is already dead.
                _state.update { it.copy(busy = false, confirm = null, error = stateMessage(pending.state)) }
                return
            }
            session = PendingSession(secret = secret, publicKey = pending.publicKey, gatewayUrl = gatewayUrl)
            _state.update {
                it.copy(
                    busy = false,
                    vouched = false,
                    confirm = PendingConfirm(name = pending.name, fingerprint = pending.fingerprint),
                )
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (refused: BackendPairingFailure.Refused) {
            // Unknown secret: show the server's code and stay on the scan screen.
            _state.update { it.copy(busy = false, confirm = null, error = refusedCode(refused)) }
        } catch (unavailable: BackendPairingFailure.Unavailable) {
            _state.update { it.copy(busy = false, confirm = null, error = unavailable.message) }
        } catch (error: Exception) {
            _state.update { it.copy(busy = false, confirm = null, error = COULD_NOT_READ) }
        }
    }

    /** A plain message for a session that can no longer be vouched for. */
    private fun stateMessage(state: String): String = when (state) {
        "expired" -> EXPIRED
        "claimed" -> CLAIMED
        "vouched" -> VOUCHED_ELSEWHERE
        else -> COULD_NOT_READ
    }

    /** "pairing refused: E_SCHEMA …" -> "E_SCHEMA". */
    private fun refusedCode(refused: BackendPairingFailure.Refused): String =
        refused.message.orEmpty().substringAfter(REFUSED_PREFIX, "E_SCHEMA").substringBefore(" ")
            .ifBlank { "E_SCHEMA" }

    private data class PendingSession(
        val secret: String,
        val publicKey: String,
        val gatewayUrl: String,
    )

    private companion object {
        const val NO_HOUSEHOLD_KEY =
            "This phone isn't connected yet. Sign in on the phone that set up the account."
        const val NOT_A_CODE = "That is not a PC pairing code."
        const val COULD_NOT_READ = "Could not read this pairing code."
        const val COULD_NOT_VOUCH = "Could not vouch for this PC."
        const val EXPIRED = "This pairing session has expired."
        const val CLAIMED = "This pairing session has already been claimed."
        const val VOUCHED_ELSEWHERE = "This pairing session was already approved on another phone."
        const val REFUSED_PREFIX = "pairing refused: "
    }
}
