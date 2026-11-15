package com.hopa.backend.pairing

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.store.Database
import java.sql.Timestamp
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.Serializable

@Serializable
data class Issued(val token: String, val expiresAt: String)

sealed interface RotateOutcome {
    data class Rotated(val access: Issued, val refresh: Issued) : RotateOutcome

    data object Refused : RotateOutcome
}

/**
 * Issues, rotates and verifies the two opaque tokens. Hashing is the only thing
 * stored; the plaintext exists in this process and on the device, nowhere else.
 */
class TokenIssuer(
    private val db: Database,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onRevoke: (deviceId: String) -> Unit = {},
) {
    fun issueAccess(deviceId: String, householdId: String, memberId: String = ""): Issued {
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

    /**
     * A refresh token is single use. Presenting one that was already rotated is
     * treated as theft: the device's whole family dies, including its live access
     * token, and the caller has to pair again.
     */
    fun rotate(refreshToken: String): RotateOutcome {
        val hash = Tokens.hex(Tokens.hash(refreshToken))
        val row = db.token(hash) { connection ->
            connection.prepareStatement(
                "select id, device_id, household_id, expires_at, revoked_at from refresh_tokens " +
                    "where token_hash = decode(?, 'hex')",
            ).use {
                it.setString(1, hash)
                it.executeQuery().use { rows ->
                    if (!rows.next()) {
                        null
                    } else {
                        RefreshRow(
                            id = rows.getString(1),
                            deviceId = rows.getString(2),
                            householdId = rows.getString(3),
                            expiresAt = rows.getTimestamp(4).toInstant().toEpochMilli(),
                            revoked = rows.getTimestamp(5) != null,
                        )
                    }
                }
            }
        } ?: return RotateOutcome.Refused

        if (row.expiresAt <= clock()) return RotateOutcome.Refused

        if (row.revoked) {
            val rotated = db.tenant(row.householdId) { connection ->
                connection.prepareStatement(
                    "select 1 from refresh_tokens where rotated_from = ?::uuid limit 1",
                ).use {
                    it.setString(1, row.id)
                    it.executeQuery().use { rows -> rows.next() }
                }
            }
            if (rotated) {
                revokeFamily(row.deviceId, row.householdId)
                onRevoke(row.deviceId)
            }
            return RotateOutcome.Refused
        }

        val won = db.tenant(row.householdId) { connection ->
            connection.prepareStatement(
                "update refresh_tokens set revoked_at = now() " +
                    "where id = ?::uuid and revoked_at is null",
            ).use {
                it.setString(1, row.id)
                it.executeUpdate()
            }
        }
        if (won != 1) {
            revokeFamily(row.deviceId, row.householdId)
            onRevoke(row.deviceId)
            return RotateOutcome.Refused
        }

        val access = issueAccess(row.deviceId, row.householdId)
        val refresh = issueRefresh(row.deviceId, row.householdId, rotatedFrom = row.id)
        return RotateOutcome.Rotated(access, refresh)
    }

    fun verify(accessToken: String): DeviceIdentity? {
        val hash = Tokens.hex(Tokens.hash(accessToken))
        val row = db.token(hash) { connection ->
            connection.prepareStatement(
                "select device_id, household_id, expires_at from access_tokens " +
                    "where token_hash = decode(?, 'hex')",
            ).use {
                it.setString(1, hash)
                it.executeQuery().use { rows ->
                    if (!rows.next()) {
                        null
                    } else {
                        TokenRow(
                            deviceId = rows.getString(1),
                            householdId = rows.getString(2),
                            expiresAt = rows.getTimestamp(3).toInstant().toEpochMilli(),
                        )
                    }
                }
            }
        } ?: return null
        if (row.expiresAt <= clock()) return null

        return db.tenant(row.householdId) { connection ->
            connection.prepareStatement(
                "select id, household_id, member_id from devices " +
                    "where id = ?::uuid and revoked_at is null",
            ).use {
                it.setString(1, row.deviceId)
                it.executeQuery().use { rows ->
                    if (!rows.next()) {
                        null
                    } else {
                        DeviceIdentity(
                            deviceId = rows.getString(1),
                            householdId = rows.getString(2),
                            memberId = rows.getString(3),
                        )
                    }
                }
            }
        }
    }

    private fun revokeFamily(deviceId: String, householdId: String) {
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "delete from access_tokens where device_id = ?::uuid",
            ).use {
                it.setString(1, deviceId)
                it.executeUpdate()
            }
            connection.prepareStatement(
                "update refresh_tokens set revoked_at = now() " +
                    "where device_id = ?::uuid and revoked_at is null",
            ).use {
                it.setString(1, deviceId)
                it.executeUpdate()
            }
        }
    }

    private data class RefreshRow(
        val id: String,
        val deviceId: String,
        val householdId: String,
        val expiresAt: Long,
        val revoked: Boolean,
    )

    private data class TokenRow(
        val deviceId: String,
        val householdId: String,
        val expiresAt: Long,
    )

    private companion object {
        const val ACCESS_MS = 15 * 60 * 1000L
        const val REFRESH_MS = 30L * 24 * 60 * 60 * 1000
    }
}
