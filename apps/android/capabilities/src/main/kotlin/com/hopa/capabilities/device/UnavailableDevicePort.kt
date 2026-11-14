package com.hopa.capabilities.device

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.ports.DevicePort
import com.hopa.core.ports.InstalledApp

class UnavailableDevicePort : DevicePort {
    override suspend fun observe(): Observation = Observation(
        id = "obs-unavailable",
        timestamp = System.currentTimeMillis(),
        screenSize = ScreenSize(width = 0, height = 0),
        text = "Device control is not connected. Connect the bridge or grant accessibility.",
        tree = ObservationNode(type = "root"),
    )

    override suspend fun tap(ref: String?, x: Int?, y: Int?) = unsupported()

    override suspend fun type(text: String, ref: String?) = unsupported()

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) =
        unsupported()

    override suspend fun pressBack() = unsupported()

    override suspend fun pressHome() = unsupported()

    override suspend fun launch(packageName: String) = unsupported()

    override suspend fun stop(packageName: String) = unsupported()

    override suspend fun foreground(): String = ""

    override suspend fun screenshot(): ByteArray? = null

    override suspend fun apps(): List<InstalledApp> = emptyList()

    private fun unsupported(): Nothing =
        throw UnsupportedOperationException("device control is not available")
}
