package com.hopa.core.testing

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.ports.DevicePort
import com.hopa.core.ports.InstalledApp

/** A device that does nothing but count, with an observation the test controls. */
class FakeDevice(
    var observation: Observation = sample(),
    private val onTap: ((FakeDevice) -> Unit)? = null,
) : DevicePort {
    var launches = 0
    var taps = 0

    override suspend fun observe(): Observation = observation

    override suspend fun tap(ref: String?, x: Int?, y: Int?) {
        taps += 1
        onTap?.invoke(this)
    }

    override suspend fun type(text: String, ref: String?) = Unit

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) = Unit

    override suspend fun pressBack() = Unit

    override suspend fun pressHome() = Unit

    override suspend fun launch(packageName: String) {
        launches += 1
    }

    override suspend fun stop(packageName: String) = Unit

    override suspend fun foreground(): String = ""

    override suspend fun screenshot(): ByteArray? = null

    override suspend fun apps(): List<InstalledApp> = emptyList()

    companion object {
        fun sample(text: String = "Settings"): Observation = Observation(
            id = "obs-test",
            timestamp = 0,
            screenSize = ScreenSize(width = 1080, height = 2400),
            text = text,
            tree = ObservationNode(type = "root"),
        )
    }
}
