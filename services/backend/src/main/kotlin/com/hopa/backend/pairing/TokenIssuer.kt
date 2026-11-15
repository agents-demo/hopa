package com.hopa.backend.pairing

import java.sql.Timestamp
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.Serializable
import com.hopa.backend.store.Database

@Serializable
data class Issued(val token: String, val expiresAt: String)

/**
 * Issues and inspects the two opaque tokens. Hashing is the only thing stored;
 * the plaintext exists in this process and on the device, nowhere else.
 */
class TokenIssuer(
    private val db: Database,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onRevoke: (deviceId: String) -> Unit = {},
) {
    fun issueAccess(deviceId: String, householdId: String, memberId: String): Issued {
        val token = Tokens.mint()
        val expiresAt = clock() + ACCESS_MS
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "insert into access_tokens(id, device_id, household_id, token_hash, expires_at) " +
                    "values (?::uuid, ?::uuid, ?::uuid, ?, ?)",
            ).use {
                it.setString(1, UUID.randomUUID().toString())
                it.setString(2, deviceId)
                it.setString(3, householdId)
                it.setBytes(4, Tokens.hash(token))
                it.setTimestamp(5, Timestamp.from(Instant.ofEpochMilli(expiresAt)))
                it.executeUpdate()
            }
        }
        return Issued(token, Instant.ofEpochMilli(expiresAt).toString())
    }

    fun issueRefresh(
        deviceId: String,
        householdId: String,
        rotatedFrom: String? = null,
    ): Issued {
        val token = Tokens.mint()
        val expiresAt = clock() + REFRESH_MS
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "insert into refresh_tokens(id, device_id, household_id, token_hash, expires_at, rotated_from) " +
                    "values (?::uuid, ?::uuid, ?::uuid, ?, ?, ?::uuid)",
            ).use {
                it.setString(1, UUID.randomUUID().toString())
                it.setString(2, deviceId)
                it.setString(3, householdId)
                it.setBytes(4, Tokens.hash(token))
                it.setTimestamp(5, Timestamp.from(Instant.ofEpochMilli(expiresAt)))
                it.setString(6, rotatedFrom)
                it.executeUpdate()
            }
        }
        return Issued(token, Instant.ofEpochMilli(expiresAt).toString())
    }

    private companion object {
        const val ACCESS_MS = 15 * 60 * 1000L
        const val REFRESH_MS = 30L * 24 * 60 * 60 * 1000
    }
}
