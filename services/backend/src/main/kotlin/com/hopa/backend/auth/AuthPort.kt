package com.hopa.backend.auth

/**
 * Resolves a bearer token to a device and the household it belongs to.
 *
 * The gateway never reads a household from the wire. Production resolves from
 * Postgres in week 2; tests supply their own implementation.
 */
interface AuthPort {
    fun deviceFor(token: String): DeviceIdentity?

    object DenyAll : AuthPort {
        override fun deviceFor(token: String): DeviceIdentity? = null
    }
}

data class DeviceIdentity(
    val deviceId: String,
    val householdId: String,
    val memberId: String,
)
