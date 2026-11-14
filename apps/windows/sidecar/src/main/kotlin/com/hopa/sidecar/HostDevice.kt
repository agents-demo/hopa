package com.hopa.sidecar

import com.hopa.core.contracts.Observation
import com.hopa.core.contracts.ObservationNode
import com.hopa.core.contracts.ScreenSize
import com.hopa.core.observation.ObservationHasher
import com.hopa.core.ports.DevicePort
import com.hopa.core.ports.InstalledApp
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.put

/**
 * W0: every device action travels to the .NET host and is executed with UI
 * Automation there. Observation is a fixed screen for now; W3 replaces it with
 * a real UIA tree.
 */
class HostDevice(private val io: Stdio) : DevicePort {
    private val pending = ConcurrentHashMap<String, CompletableDeferred<Boolean>>()
    private val counter = AtomicInteger(0)

    fun resolve(id: String, ok: Boolean) {
        pending.remove(id)?.complete(ok)
    }

    override suspend fun observe(): Observation {
        val tree = ObservationNode(
            type = "root",
            children = listOf(
                ObservationNode(
                    ref = "e1",
                    type = "window",
                    text = "Notepad",
                    children = listOf(
                        ObservationNode(ref = "e2", type = "edit", text = "Untitled"),
                    ),
                ),
            ),
        )
        val observation = Observation(
            id = "win-spike-${System.currentTimeMillis()}",
            timestamp = System.currentTimeMillis(),
            screenSize = ScreenSize(width = 1920, height = 1080),
            text = "Notepad\nUntitled",
            tree = tree,
            app = "notepad",
        )
        return observation.copy(hash = ObservationHasher.hash(observation))
    }

    override suspend fun tap(ref: String?, x: Int?, y: Int?) {
        request("tap") {
            ref?.let { put("ref", it) }
            x?.let { put("x", it) }
            y?.let { put("y", it) }
        }
    }

    override suspend fun doubleTap(ref: String?, x: Int?, y: Int?) {
        request("doubleTap") {
            ref?.let { put("ref", it) }
            x?.let { put("x", it) }
            y?.let { put("y", it) }
        }
    }

    override suspend fun longPress(ref: String?, x: Int?, y: Int?) {
        request("longPress") {
            ref?.let { put("ref", it) }
            x?.let { put("x", it) }
            y?.let { put("y", it) }
        }
    }

    override suspend fun type(text: String, ref: String?) {
        request("type") {
            put("text", text)
            ref?.let { put("ref", it) }
        }
    }

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) {
        request("swipe") {
            put("fromX", fromX)
            put("fromY", fromY)
            put("toX", toX)
            put("toY", toY)
        }
    }

    override suspend fun pressBack() {
        request("key") { put("key", "back") }
    }

    override suspend fun pressHome() {
        request("key") { put("key", "home") }
    }

    override suspend fun launch(packageName: String) {
        request("launch") { put("app", packageName) }
    }

    override suspend fun stop(packageName: String) {
        throw UnsupportedOperationException("W0 does not stop apps")
    }

    override suspend fun foreground(): String = "notepad"

    override suspend fun screenshot(): ByteArray? = null

    override suspend fun apps(): List<InstalledApp> = emptyList()

    private suspend fun request(op: String, fields: JsonObjectBuilder.() -> Unit) {
        val id = "req-${counter.incrementAndGet()}"
        val deferred = CompletableDeferred<Boolean>()
        pending[id] = deferred
        io.send(Protocol.deviceRequest(id, op, fields))
        val ok = withTimeout(15_000) { deferred.await() }
        if (!ok) {
            throw IllegalStateException("the host could not $op; see its log")
        }
    }
}
