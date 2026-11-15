package com.hopa.backend.pairing

import com.hopa.backend.auth.AuthPort
import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.store.Database
import java.util.concurrent.ConcurrentHashMap

/**
 * Resolves an opaque access token to its device, with a five second cache so a
 * chatty socket does not pay a database read per frame. `revoke` clears the
 * device's entries immediately; the TTL only bounds how long a token that was
 * deleted out-of-band can still resolve.
 */
class PgAuth(
    private val db: Database,
    private val clock: () -> Long = System::currentTimeMillis,
    private val cacheTtlMs: Long = 5_000,
) : AuthPort {
    private data class Cached(val identity: DeviceIdentity, val until: Long)

    private val cache = ConcurrentHashMap<String, Cached>()

    override fun deviceFor(token: String): DeviceIdentity? {
        val hash = Tokens.hex(Tokens.hash(token))
        val now = clock()

        cache[hash]?.let { cached ->
            if (cached.until > now) return cached.identity
            cache.remove(hash)
        }

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

        if (row.expiresAt <= now) return null

        val identity = db.tenant(row.householdId) { connection ->
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
        } ?: return null

        cache[hash] = Cached(identity, now + cacheTtlMs)
        return identity
    }

    /** Called on rotation reuse and on an explicit revoke. */
    fun revoke(deviceId: String) {
        cache.entries.removeIf { entry -> entry.value.identity.deviceId == deviceId }
    }

    private data class TokenRow(
        val deviceId: String,
        val householdId: String,
        val expiresAt: Long,
    )
}
