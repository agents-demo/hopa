package com.hopa.backend.harness

import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.tasks.DeviceDirectory

/** Every paired device, online or not. Production reads Postgres. */
class MapDirectory(
    private val byId: Map<String, DeviceIdentity>,
) : DeviceDirectory {
    override fun lookup(deviceId: String, householdId: String): DeviceIdentity? =
        byId[deviceId]?.takeIf { it.householdId == householdId }
}
