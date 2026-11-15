package com.hopa.backend.pairing

import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

/**
 * Opaque tokens: 32 random bytes in base64url, and the SHA-256 that is the only
 * form ever written to the database.
 */
object Tokens {
    private val random = SecureRandom()

    fun mint(): String {
        val bytes = ByteArray(32)
        random.nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    fun hash(token: String): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(token.toByteArray(Charsets.UTF_8))

    fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }
}
