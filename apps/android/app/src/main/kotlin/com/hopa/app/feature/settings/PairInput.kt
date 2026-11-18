package com.hopa.app.feature.settings

import com.hopa.net.backend.PairingLink
import com.hopa.net.backend.PairingLinks

/**
 * The one field that takes either a whole `hopa://pair…` link or a bare
 * session typed next to a stored gateway. Parsing lives in [PairingLinks]; this
 * names the screen's entry point so the UI and its test agree.
 */
object PairInput {
    fun normalise(text: String, fallbackGatewayUrl: String): PairingLink? =
        PairingLinks.parse(text, fallbackGatewayUrl)
}
