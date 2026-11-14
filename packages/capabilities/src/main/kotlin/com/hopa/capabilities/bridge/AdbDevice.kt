package com.hopa.capabilities.bridge

import com.hopa.core.contracts.Observation
import com.hopa.core.ports.Clock
import com.hopa.core.ports.DevicePort
import com.hopa.core.ports.InstalledApp

/**
 * `DevicePort` over the PC bridge: the phone is driven by adb on the PC, which
 * is the primary path (ADR-0017). Refs are resolved to bounds from the last
 * observation, because the bridge taps coordinates.
 */
class AdbDevice(
    private val client: BridgeClient,
    private val clock: Clock,
) : DevicePort {
    private var points: Map<String, Pair<Int, Int>> = emptyMap()

    override suspend fun observe(): Observation {
        val payload = client.observe()
        val app = runCatching { client.foreground() }.getOrDefault("")
        val timestamp = clock.nowMillis()
        val observation = BridgeObservation.fromJson(
            payload = payload,
            app = app,
            timestamp = timestamp,
            id = "obs-$timestamp",
        )
        points = buildMap {
            for (node in observation.tree.children) {
                val bounds = node.bounds ?: continue
                if (bounds.size != 4) continue
                put(
                    node.ref,
                    (bounds[0] + bounds[2]) / 2 to (bounds[1] + bounds[3]) / 2,
                )
            }
        }
        return observation
    }

    override suspend fun tap(ref: String?, x: Int?, y: Int?) {
        val point = resolve(ref, x, y)
        client.tap(point.first, point.second)
    }

    override suspend fun doubleTap(ref: String?, x: Int?, y: Int?) {
        val point = resolve(ref, x, y)
        client.tap(point.first, point.second)
        client.tap(point.first, point.second)
    }

    override suspend fun longPress(ref: String?, x: Int?, y: Int?) {
        val point = resolve(ref, x, y)
        client.swipe(point.first, point.second, point.first, point.second, velocity = 200)
    }

    override suspend fun type(text: String, ref: String?) {
        val point = ref?.let { points[it] }
        client.type(text, point?.first, point?.second)
    }

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) {
        client.swipe(fromX, fromY, toX, toY, velocity)
    }

    override suspend fun pressBack() = client.key("back")

    override suspend fun pressHome() = client.key("home")

    override suspend fun launch(packageName: String) {
        client.launch(packageName)
    }

    override suspend fun stop(packageName: String) {
        client.stop(packageName)
    }

    override suspend fun foreground(): String = client.foreground()

    override suspend fun screenshot(): ByteArray? =
        runCatching { client.screenshot() }.getOrNull()

    override suspend fun apps(): List<InstalledApp> = client.apps()

    private fun resolve(ref: String?, x: Int?, y: Int?): Pair<Int, Int> = when {
        ref != null -> points[ref] ?: throw IllegalArgumentException("unknown ref $ref")
        x != null && y != null -> x to y
        else -> throw IllegalArgumentException("a gesture needs a ref or coordinates")
    }
}
