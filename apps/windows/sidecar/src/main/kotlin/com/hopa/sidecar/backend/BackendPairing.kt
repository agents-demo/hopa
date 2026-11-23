package com.hopa.sidecar.backend

import com.hopa.backend.crypto.KeyWrap
import com.hopa.backend.pairing.AdmissionLinks
import com.hopa.backend.pairing.BackendCredentials
import com.hopa.backend.pairing.BackendPairingFailure
import com.hopa.backend.pairing.BackendPairing as CorePairing
import com.hopa.backend.pairing.X25519Keys
import java.nio.file.Files
import java.nio.file.Path
import java.security.MessageDigest
import java.util.Base64
import kotlinx.coroutines.delay

/**
 * What an admitted PC keeps: the backend credentials and the 32-byte household
 * content key. The PKCS#8 private half is persisted in [BackendSession] rather
 * than exposed here (Task 8 loads it back from the store).
 */
data class AdmissionResult(
    val credentials: BackendCredentials,
    val contentKey: ByteArray,
) {
    override fun toString(): String =
        "AdmissionResult(credentials=$credentials, contentKey=<redacted>)"
}

/**
 * The PC side of admission. Generates its X25519 key, mints a pending session,
 * shows the QR to a phone, polls until the phone vouches, then claims and
 * unwraps the household key with the vouching phone's public key.
 *
 * `out` is the host's seam for showing the QR: the default writes to stderr
 * because stdout is the sidecar's JSON protocol channel. Host UIs inject their
 * own sink; tests capture the lines. This file holds no LAN or bridge code: the
 * only channel to the phone is the backend, and the content key never leaves
 * except wrapped.
 */
class BackendPairing(
    private val dataDir: Path,
    private val clientFor: (String) -> CorePairing = { CorePairing(it) },
    private val out: (String) -> Unit = { System.err.println(it) },
    private val sleep: suspend (Long) -> Unit = { delay(it) },
    private val now: () -> Long = System::currentTimeMillis,
    private val store: BackendSessionStore = BackendSessionStore(dataDir.resolve(SESSION_FILE)),
) {
    suspend fun admit(backendUrl: String, name: String): AdmissionResult {
        val privateKey = X25519Keys.generatePrivateKey()
        val publicKey = X25519Keys.publicKeyBytes(privateKey)
        val publicKeyText = base64Url(publicKey)
        val client = clientFor(backendUrl)
        val qrPath = dataDir.resolve(QR_PNG)
        try {
            val pending = client.mintPending(name, publicKeyText)
            // The gateway URL is server-authoritative: it comes back in the
            // minted QR, not from whatever URL the caller typed.
            val admission = AdmissionLinks.parse(pending.qr)
                ?: throw IllegalStateException("mint returned a malformed pairing link")
            if (admission.session != pending.secret) {
                throw IllegalStateException("mint returned a QR for a different session")
            }
            val matrix = QrRender.matrix(pending.qr)
            out("Scan this QR with the HOPA phone:")
            out(pending.qr)
            out(QrRender.blocks(matrix))
            out("fingerprint: ${fingerprint(publicKey)}")
            QrRender.writePng(matrix, qrPath)

            awaitVouch(client, pending.secret)

            val claimed = client.claimPending(pending.secret, name, publicKeyText)
            val wrapped = claimed.wrappedKey
                ?.let(::decodeBase64)
                ?: throw IllegalStateException("claim returned no wrapped key")
            val voucherPublicKey = claimed.voucherPublicKey
                ?.let(::decodeBase64)
                ?: throw IllegalStateException("claim returned no voucher public key")
            val contentKey = try {
                KeyWrap.unwrapByDevice(wrapped, voucherPublicKey, privateKey)
            } catch (failure: Exception) {
                throw IllegalStateException("could not unwrap the household key", failure)
            }
            if (contentKey.size != CONTENT_KEY_BYTES) {
                throw IllegalStateException("household key is not $CONTENT_KEY_BYTES bytes")
            }

            store.save(
                BackendSession(
                    deviceId = claimed.credentials.deviceId,
                    householdId = claimed.credentials.householdId,
                    accessToken = claimed.credentials.accessToken,
                    refreshToken = claimed.credentials.refreshToken,
                    expiresAt = claimed.credentials.expiresAt,
                    gatewayUrl = admission.gatewayUrl,
                    contentKeyBase64 = Base64.getEncoder().encodeToString(contentKey),
                    privateKeyBase64 = Base64.getEncoder().encodeToString(privateKey),
                ),
            )
            out("admitted as ${claimed.credentials.deviceId} to household ${claimed.credentials.householdId}")
            return AdmissionResult(
                claimed.credentials.copy(gatewayUrl = admission.gatewayUrl),
                contentKey,
            )
        } finally {
            // The PNG holds the live secret until the session ends; the claim,
            // expiry, a failure or a timeout is terminal, so it never outlives
            // this call.
            runCatching { Files.deleteIfExists(qrPath) }
        }
    }

    /**
     * Poll every five seconds (R24) until the phone vouches, with a five-minute
     * deadline. A 429 or an unreachable backend doubles the wait up to 30 s
     * instead of hot-looping; a successful pending poll resets the pace.
     */
    private suspend fun awaitVouch(client: CorePairing, secret: String) {
        val deadline = now() + DEADLINE_MS
        var interval = POLL_INTERVAL_MS
        while (true) {
            val remaining = deadline - now()
            if (remaining <= 0) {
                throw IllegalStateException("pairing session timed out after five minutes")
            }
            try {
                val state = client.pollPending(secret).state
                when (state) {
                    "vouched" -> return
                    "claimed" -> throw IllegalStateException("pairing session was already claimed")
                    "expired" -> throw IllegalStateException(
                        "pairing session expired before a phone vouched for it",
                    )
                    "pending" -> {
                        interval = POLL_INTERVAL_MS
                        sleep(minOf(interval, remaining))
                    }
                    else -> throw IllegalStateException("unexpected pairing state: $state")
                }
            } catch (_: BackendPairingFailure.Unavailable) {
                interval = minOf(interval * 2, MAX_BACKOFF_MS)
                sleep(minOf(interval, remaining))
            }
        }
    }

    private fun fingerprint(publicKey: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(publicKey)
            .joinToString("") { "%02x".format(it) }
            .take(8)

    private fun decodeBase64(value: String): ByteArray =
        runCatching { Base64.getDecoder().decode(value) }
            .recoverCatching { Base64.getUrlDecoder().decode(value) }
            .getOrElse { throw IllegalStateException("pairing returned malformed base64") }

    private fun base64Url(bytes: ByteArray): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

    private companion object {
        const val SESSION_FILE = "backend-session.json"
        const val QR_PNG = "pair-qr.png"
        const val CONTENT_KEY_BYTES = 32
        const val POLL_INTERVAL_MS = 5_000L
        const val MAX_BACKOFF_MS = 30_000L
        const val DEADLINE_MS = 5 * 60 * 1000L
    }
}
