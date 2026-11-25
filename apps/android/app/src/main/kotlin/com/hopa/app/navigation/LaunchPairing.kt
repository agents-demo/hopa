package com.hopa.app.navigation

import com.hopa.feature.settings.PairInput
import com.hopa.backend.pairing.PairingLink
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * The gateway half of a launch config. It parses the extras once and records a
 * refusal or a failed claim where the Backend card can show it. It never
 * retries: a pairing session is one-shot, so an Activity recreation must not
 * spend it a second time.
 */
object LaunchPairing {
    suspend fun apply(
        backendUrl: String?,
        backendPair: String?,
        notice: MutableStateFlow<String?>,
        storeUrl: suspend (String) -> Unit,
        claim: suspend (PairingLink) -> Result<Unit>,
    ) {
        val fallback = backendUrl?.trim().orEmpty()
        if (backendPair.isNullOrBlank()) {
            // An address without a session is a valid arrangement for a later
            // pair; nothing is claimed.
            if (fallback.isNotBlank()) {
                storeUrl(fallback)
            }
            return
        }
        val link = PairInput.normalise(backendPair, fallback)
        if (link == null) {
            if (fallback.isNotBlank()) {
                storeUrl(fallback)
            }
            notice.value = "Couldn't pair: the link isn't valid"
            return
        }
        claim(link).onFailure { error ->
            notice.value = "Couldn't pair: " + (error.message ?: "try again")
        }
    }
}
