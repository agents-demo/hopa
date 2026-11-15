package com.hopa.backend.pairing

import com.hopa.backend.http.RateLimiter
import com.hopa.backend.store.Database
import java.sql.Timestamp
import java.time.Instant
import java.util.Base64
import java.util.UUID

/**
 * The pairing flow: an operator mints a single-use session, the new device
 * claims it with its public key, and the household of one is created on first
 * use (week 2 turns that member into a signed-in account).
 */
class PairingService(
    private val db: Database,
    private val clock: () -> Long = System::currentTimeMillis,
    private val publicHost: String =
        System.getenv("HOPA_PUBLIC_HOST") ?: "hopa-backend.onrender.com",
    private val tokens: TokenIssuer = TokenIssuer(db, clock),
    perMinute: Int = 5,
) : PairingApi {
    private val mintLimiter = RateLimiter(perMinute, 60_000, clock)
    private val claimLimiter = RateLimiter(perMinute, 60_000, clock)

    override fun mint(
        householdName: String,
        memberName: String,
        remoteAddress: String,
        householdId: String?,
    ): PairingOutcome<Minted> {
        if (!mintLimiter.allow(remoteAddress)) {
            return PairingOutcome.Refused("E_RATE", "too many pairing sessions", retryable = true)
        }

        val household = householdId ?: UUID.randomUUID().toString()
        if (householdId != null) {
            val exists = db.tenant(householdId) { connection ->
                connection.createStatement().use { statement ->
                    statement.executeQuery("select count(*) from households").use { rows ->
                        rows.next()
                        rows.getInt(1) == 1
                    }
                }
            }
            if (!exists) {
                return PairingOutcome.Refused("E_SCHEMA", "unknown household")
            }
        }
        val member = UUID.randomUUID().toString()
        val session = Tokens.mint()
        val expiresAt = clock() + SESSION_MS

        db.tenant(household) { connection ->
            if (householdId == null) {
                connection.prepareStatement("insert into households(id, name) values (?::uuid, ?)").use {
                    it.setString(1, household)
                    it.setString(2, householdName)
                    it.executeUpdate()
                }
            }
            connection.prepareStatement(
                "insert into members(id, household_id, role, display_name) " +
                    "values (?::uuid, ?::uuid, 'owner', ?)",
            ).use {
                it.setString(1, member)
                it.setString(2, household)
                it.setString(3, memberName)
                it.executeUpdate()
            }
            connection.prepareStatement(
                "insert into pairing_sessions(id, household_id, member_id, code_hash, expires_at) " +
                    "values (?::uuid, ?::uuid, ?::uuid, ?, ?)",
            ).use {
                it.setString(1, UUID.randomUUID().toString())
                it.setString(2, household)
                it.setString(3, member)
                it.setBytes(4, Tokens.hash(session))
                it.setTimestamp(5, Timestamp.from(Instant.ofEpochMilli(expiresAt)))
                it.executeUpdate()
            }
        }

        val qr = "hopa://pair?v=1&h=$household&p=$session&u=wss://$publicHost/v1/gateway"
        return PairingOutcome.Ok(Minted(session, qr, Instant.ofEpochMilli(expiresAt).toString()))
    }

    override fun claim(request: ClaimRequest, remoteAddress: String): PairingOutcome<Claimed> {
        if (!claimLimiter.allow(remoteAddress)) {
            return PairingOutcome.Refused("E_RATE", "too many pairing claims", retryable = true)
        }
        if (request.platform !in PLATFORMS) {
            return PairingOutcome.Refused("E_SCHEMA", "platform must be android or windows")
        }
        if (request.alg != "x25519") {
            return PairingOutcome.Refused("E_SCHEMA", "alg must be x25519")
        }
        val publicKey = decodeKey(request.publicKey)
            ?: return PairingOutcome.Refused("E_SCHEMA", "publicKey is not base64")
        if (publicKey.size != 32) {
            return PairingOutcome.Refused("E_SCHEMA", "publicKey must be 32 bytes")
        }

        val hash = Tokens.hex(Tokens.hash(request.session))
        val session = db.token(hash) { connection ->
            connection.prepareStatement(
                "select id, household_id, member_id, expires_at, claimed_at " +
                    "from pairing_sessions where code_hash = decode(?, 'hex')",
            ).use {
                it.setString(1, hash)
                it.executeQuery().use { rows ->
                    if (!rows.next()) {
                        null
                    } else {
                        SessionRow(
                            id = rows.getString(1),
                            householdId = rows.getString(2),
                            memberId = rows.getString(3),
                            expiresAt = rows.getTimestamp(4).toInstant().toEpochMilli(),
                            claimed = rows.getTimestamp(5) != null,
                        )
                    }
                }
            }
        } ?: return PairingOutcome.Refused("E_SCHEMA", "unknown pairing session")

        if (session.claimed) {
            return PairingOutcome.Refused("E_SCHEMA", "pairing session already claimed")
        }
        if (session.expiresAt <= clock()) {
            return PairingOutcome.Refused("E_SCHEMA", "pairing session expired")
        }

        val device = UUID.randomUUID().toString()
        try {
            db.tenant(session.householdId) { connection ->
                val won = connection.prepareStatement(
                    "update pairing_sessions set claimed_at = now() " +
                        "where id = ?::uuid and claimed_at is null",
                ).use {
                    it.setString(1, session.id)
                    it.executeUpdate()
                }
                if (won != 1) throw SessionTaken()

                connection.prepareStatement(
                    "insert into devices(id, household_id, member_id, platform, name, " +
                        "public_key, alg, push_token) values (?::uuid, ?::uuid, ?::uuid, ?, ?, ?, ?, ?)",
                ).use {
                    it.setString(1, device)
                    it.setString(2, session.householdId)
                    it.setString(3, session.memberId)
                    it.setString(4, request.platform)
                    it.setString(5, request.name)
                    it.setBytes(6, publicKey)
                    it.setString(7, request.alg)
                    it.setString(8, request.pushToken)
                    it.executeUpdate()
                }
            }
        } catch (_: SessionTaken) {
            return PairingOutcome.Refused("E_SCHEMA", "pairing session already claimed")
        }

        val access = tokens.issueAccess(device, session.householdId, session.memberId)
        val refresh = tokens.issueRefresh(device, session.householdId)
        return PairingOutcome.Ok(
            Claimed(
                deviceId = device,
                householdId = session.householdId,
                accessToken = access.token,
                refreshToken = refresh.token,
                expiresAt = access.expiresAt,
            ),
        )
    }

    private fun decodeKey(value: String): ByteArray? =
        try {
            Base64.getDecoder().decode(value)
        } catch (_: IllegalArgumentException) {
            try {
                Base64.getUrlDecoder().decode(value)
            } catch (_: IllegalArgumentException) {
                null
            }
        }

    private data class SessionRow(
        val id: String,
        val householdId: String,
        val memberId: String,
        val expiresAt: Long,
        val claimed: Boolean,
    )

    private class SessionTaken : RuntimeException()

    private companion object {
        const val SESSION_MS = 5 * 60 * 1000L
        val PLATFORMS = setOf("android", "windows")
    }
}
