package com.hopa.backend.store

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.tasks.DeviceDirectory
import java.sql.Timestamp
import java.time.Instant

/** The paired-device directory, read and written behind row-level security. */
class PgDevices(private val db: Database) : DeviceDirectory {
    override fun lookup(deviceId: String, householdId: String): DeviceIdentity? =
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "select id, household_id, member_id from devices " +
                    "where id = ?::uuid and revoked_at is null",
            ).use {
                it.setString(1, deviceId)
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

    override fun pushToken(deviceId: String, householdId: String): String? =
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "select push_token from devices where id = ?::uuid and revoked_at is null",
            ).use {
                it.setString(1, deviceId)
                it.executeQuery().use { rows -> if (rows.next()) rows.getString(1) else null }
            }
        }

    override fun touch(deviceId: String, householdId: String, pushToken: String?, at: Long) {
        db.tenant(householdId) { connection ->
            val sql = if (pushToken == null) {
                "update devices set last_seen_at = ? where id = ?::uuid"
            } else {
                "update devices set last_seen_at = ?, push_token = ? where id = ?::uuid"
            }
            connection.prepareStatement(sql).use {
                var index = 1
                it.setTimestamp(index++, Timestamp.from(Instant.ofEpochMilli(at)))
                if (pushToken != null) it.setString(index++, pushToken)
                it.setString(index, deviceId)
                it.executeUpdate()
            }
        }
    }

    override fun clearPushToken(deviceId: String, householdId: String) {
        db.tenant(householdId) { connection ->
            connection.prepareStatement(
                "update devices set push_token = null where id = ?::uuid",
            ).use {
                it.setString(1, deviceId)
                it.executeUpdate()
            }
        }
    }
}
