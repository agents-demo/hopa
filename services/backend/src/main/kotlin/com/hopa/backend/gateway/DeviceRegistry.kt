package com.hopa.backend.gateway

import com.hopa.backend.auth.DeviceIdentity
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.channels.Channel

/**
 * Who is connected right now, and how to reach them.
 *
 * Presence is in memory on purpose: a socket only exists on the process that
 * holds it, and the durable record of a task is the Postgres row (slice B).
 */
class DeviceRegistry {
    data class Session(
        val identity: DeviceIdentity,
        val outgoing: Channel<String>,
    )

    private val sessions = ConcurrentHashMap<String, Session>()

    fun join(session: Session) {
        sessions[session.identity.deviceId] = session
    }

    fun leave(deviceId: String) {
        sessions.remove(deviceId)
    }

    fun online(deviceId: String): Boolean = sessions.containsKey(deviceId)

    fun householdSessions(householdId: String): List<Session> =
        sessions.values
            .filter { it.identity.householdId == householdId }
            .sortedBy { it.identity.deviceId }

    fun peers(householdId: String, exceptDeviceId: String): List<Session> =
        householdSessions(householdId).filter { it.identity.deviceId != exceptDeviceId }

    fun deviceIds(householdId: String): List<String> =
        householdSessions(householdId).map { it.identity.deviceId }
}
