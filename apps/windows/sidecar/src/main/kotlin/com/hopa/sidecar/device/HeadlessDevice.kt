package com.hopa.sidecar.device

import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.ports.InstalledApp
import com.hopa.contracts.wire.Observation

/**
 * P1: the headless device.
 *
 * `--turn` has no .NET host, so there is no screen and no way to act. It says so
 * instead of pretending: `observe` fails, which makes the loop treat the surface
 * as unavailable, and every action refuses with `E_UNSUPPORTED`.
 *
 * Reads that can honestly be empty (`screenshot`, `apps`, `foreground`) return
 * empty values, because those are facts about a missing host, not permissions.
 */
class HeadlessDevice : DevicePort {
    override suspend fun observe(): Observation = throw unsupported("observe")

    override suspend fun tap(ref: String?, x: Int?, y: Int?) = throw unsupported("tap")

    override suspend fun type(text: String, ref: String?) = throw unsupported("type")

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) =
        throw unsupported("swipe")

    override suspend fun pressBack() = throw unsupported("back")

    override suspend fun pressHome() = throw unsupported("home")

    override suspend fun launch(packageName: String) = throw unsupported("launch")

    override suspend fun stop(packageName: String) = throw unsupported("stop")

    override suspend fun foreground(): String = ""

    override suspend fun screenshot(): ByteArray? = null

    override suspend fun apps(): List<InstalledApp> = emptyList()

    private fun unsupported(op: String): UnsupportedOperationException =
        UnsupportedOperationException("no device is attached in headless mode; cannot $op")
}
