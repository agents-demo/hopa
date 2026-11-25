package com.hopa.app.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.backend.accounts.Phones
import com.hopa.backend.crypto.KeyWrap
import com.hopa.backend.pairing.AccountClient
import com.hopa.backend.pairing.BackendPairingFailure
import com.hopa.backend.pairing.SignedInAccount
import com.hopa.backend.pairing.X25519Keys
import com.hopa.stores.SettingsRepository
import java.util.Base64
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Phone + password sign-in and sign-up. Sign-up generates the phone's X25519
 * keypair and a 32-byte content key, wraps the content key for itself and posts
 * the wrap; sign-in generates a fresh keypair and posts no key material (history
 * stays unreadable until a wrap is sent). A refused sign-in and a refused
 * sign-up surface as one uniform message, so a wrong phone and a wrong password
 * are indistinguishable. No phone, password or token is ever put in a message.
 */
class AccountViewModel(
    private val settings: SettingsRepository,
    private val gatewayUrl: String,
    private val deviceName: String = "Android",
    private val pushToken: () -> String? = { null },
    private val accountClient: (String) -> AccountClient = { AccountClient(it) },
) : ViewModel() {
    private val _state = MutableStateFlow(AccountUiState())
    val state: StateFlow<AccountUiState> = _state.asStateFlow()

    fun signIn(phone: String, password: String) {
        viewModelScope.launch { submit(phone, password, signUp = false) }
    }

    fun signUp(phone: String, password: String) {
        viewModelScope.launch { submit(phone, password, signUp = true) }
    }

    private suspend fun submit(phone: String, password: String, signUp: Boolean) {
        _state.update { it.copy(busy = true, error = null) }
        val normalized = Phones.normalize(phone)
        if (normalized == null) {
            _state.update { it.copy(busy = false, error = AUTH_FAILED) }
            return
        }
        val keys = X25519Keys.generate()
        val publicKey = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(X25519Keys.publicKeyBytes(keys.public))
        val privateKey = X25519Keys.privateKeyBase64(keys.private)
        try {
            if (signUp) {
                val contentKey = KeyWrap.generateContentKey()
                val wrapped = KeyWrap.wrapForDevice(
                    contentKey = contentKey,
                    peerPublicKey = X25519Keys.publicKeyBytes(keys.public),
                    ownPrivateKey = keys.private.encoded,
                )
                val selfWrappedKey = Base64.getUrlEncoder().withoutPadding().encodeToString(wrapped)
                val account = accountClient(gatewayUrl).signUp(
                    phone = normalized,
                    password = password,
                    platform = PLATFORM,
                    name = deviceName,
                    publicKey = publicKey,
                    alg = ALG,
                    selfWrappedKey = selfWrappedKey,
                    pushToken = pushToken(),
                )
                persist(account, privateKey)
                settings.setBackendContentKey(Base64.getEncoder().encodeToString(contentKey))
            } else {
                val account = accountClient(gatewayUrl).signIn(
                    phone = normalized,
                    password = password,
                    platform = PLATFORM,
                    name = deviceName,
                    publicKey = publicKey,
                    pushToken = pushToken(),
                )
                persist(account, privateKey)
            }
            _state.update { it.copy(busy = false, signedIn = true) }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (refused: BackendPairingFailure.Refused) {
            // A throttled account is not an unreachable gateway and not a wrong
            // phone or password: say so, never "unreachable".
            _state.update {
                it.copy(
                    busy = false,
                    error = if (refused.status == 429) RATE_LIMITED else AUTH_FAILED,
                )
            }
        } catch (unavailable: BackendPairingFailure.Unavailable) {
            _state.update { it.copy(busy = false, error = UNREACHABLE) }
        } catch (error: Exception) {
            _state.update { it.copy(busy = false, error = GENERIC) }
        }
    }

    private suspend fun persist(account: SignedInAccount, privateKey: String) {
        settings.update {
            it.copy(
                backendUrl = gatewayUrl,
                backendDeviceId = account.deviceId,
                backendHouseholdId = account.householdId,
                accountSkipped = false,
            )
        }
        settings.setBackendAccessToken(account.accessToken)
        settings.setBackendRefreshToken(account.refreshToken)
        settings.setBackendPrivateKey(privateKey)
    }

    private companion object {
        const val PLATFORM = "android"
        const val ALG = "x25519"
        const val AUTH_FAILED = "Invalid phone or password."
        const val RATE_LIMITED = "Too many attempts. Try again in a minute."
        const val UNREACHABLE = "Can't reach your account. Check your connection and try again."
        const val GENERIC = "Something went wrong."
    }
}
