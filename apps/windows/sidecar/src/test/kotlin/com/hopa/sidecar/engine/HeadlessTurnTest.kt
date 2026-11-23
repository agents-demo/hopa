package com.hopa.sidecar.engine

import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.error.ErrorCodes
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.ports.InstalledApp
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.ScreenSize
import com.hopa.sidecar.protocol.Protocol.text
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

import com.hopa.sidecar.approval.DenyAllApproval
import com.hopa.sidecar.config.RuntimeConfig
import com.hopa.sidecar.device.HeadlessDevice
import com.hopa.sidecar.device.HostDevice
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.support.Stdio

/**
 * P1: the engine runs through the real loop and the real gate without a window.
 *
 * The three claims this file defends:
 * 1. a plain turn answers and writes no record;
 * 2. a payment is refused before the device is touched;
 * 3. a benign action still reaches the device, so the refusal is specific.
 */
class HeadlessTurnTest {
    @Test
    fun say_hello_answers_through_the_real_loop() {
        val dataDir = Files.createTempDirectory("hopa-p1-hello")

        val outcome = runBlocking { engine(dataDir).runTurn("t-hello", "say hello", null) }

        assertTrue(outcome.answer.startsWith("Stub answered"), outcome.answer)
        assertEquals(0, outcome.records.size)
        assertTrue(outcome.chainOk)
        assertNull(outcome.error)
    }

    @Test
    fun payment_is_refused_before_the_device_is_touched() {
        val dataDir = Files.createTempDirectory("hopa-p1-pay")
        val device = RecordingDevice()
        val approvals = DenyAllApproval()

        val outcome = runBlocking {
            engine(dataDir, device, approvals).runTurn("t-pay", "pay 100 for the order", null)
        }

        val record = outcome.records.single()
        assertEquals("payment", record.classification)
        assertEquals(false, record.approved)
        assertEquals(false, record.executed)
        assertEquals(ErrorCodes.REFUSED, record.error)
        assertEquals(1, approvals.requests)
        assertTrue(device.taps.isEmpty(), "the denied payment must not reach the device")
        assertEquals("I did not run that.", outcome.answer)
        assertTrue(outcome.chainOk)
    }

    @Test
    fun a_read_action_reaches_the_device() {
        val dataDir = Files.createTempDirectory("hopa-p1-tap")
        val device = RecordingDevice()

        val outcome = runBlocking {
            engine(dataDir, device).runTurn("t-tap", "click the save button", null)
        }

        val record = outcome.records.single()
        assertEquals("read", record.classification)
        assertNull(record.approved, "a read action needs no approval")
        assertTrue(record.executed)
        assertEquals(1, device.taps.size)
    }

    @Test
    fun launch_reaches_the_device() {
        val dataDir = Files.createTempDirectory("hopa-p1-launch")
        val device = RecordingDevice()

        val outcome = runBlocking {
            engine(dataDir, device).runTurn("t-launch", "open notepad", null)
        }

        assertEquals(listOf("notepad"), device.launches)
        assertTrue(outcome.records.single().executed)
    }

    @Test
    fun the_headless_device_refuses_instead_of_pretending() {
        val dataDir = Files.createTempDirectory("hopa-p1-no-device")
        val engine = Engine(
            io = Stdio(),
            hostDevice = HeadlessDevice(),
            approval = DenyAllApproval(),
            store = ChatStore(dataDir.resolve("conversations.json")),
            recordStore = RecordStore(dataDir.resolve("records.json")),
            config = RuntimeConfig(),
            forceStub = true,
            deviceAttached = false,
        )

        val outcome = runBlocking { engine.runTurn("t-nothing", "click the save button", null) }

        val record = outcome.records.single()
        assertFalse(record.executed)
        assertEquals(ErrorCodes.UNSUPPORTED, record.error)
        assertTrue(outcome.answer.startsWith("I could not do that:"), outcome.answer)
    }

    @Test
    fun an_unavailable_intent_tier_falls_back_to_the_uia_launch() {
        val dataDir = Files.createTempDirectory("hopa-p3-fallback")
        val device = RecordingDevice()

        // No HostDevice is attached, so the sidecar has no system port. The
        // intent tier for "open wifi settings" is unavailable and must fall
        // through to the plain UIA launch the selector kept as a second path.
        val outcome = runBlocking {
            engine(dataDir, device).runTurn("t-fallback", "open wifi settings", null)
        }

        assertEquals(listOf("wifi"), device.launches)
        val record = outcome.records.single()
        assertEquals("uia", record.tier)
        assertTrue(record.executed)
        assertNull(record.error)
        assertTrue(outcome.chainOk)
    }

    @Test
    fun a_second_turn_keeps_the_conversation_and_the_records() {
        val dataDir = Files.createTempDirectory("hopa-p1-restart")
        val conversations = dataDir.resolve("conversations.json")
        val records = dataDir.resolve("records.json")
        val device = RecordingDevice()

        val first = runBlocking {
            engine(dataDir, device).runTurn("t-one", "click the save button", null)
        }
        runBlocking {
            engine(dataDir, device).runTurn("t-two", "say hello", first.conversationId)
        }

        val reloaded = ChatStore(conversations).get(first.conversationId)
        assertEquals(4, reloaded?.messages?.size)
        assertEquals(1, RecordStore(records).count())
    }

    @Test
    fun a_turn_from_the_envelope_matches_the_stored_turn() {
        val dataDir = Files.createTempDirectory("hopa-p1-envelope")
        val outcome = runBlocking { engine(dataDir).runTurn("t-env", "say hello", null) }

        val envelope = Protocol.headlessTurn("t-env", outcome)
        assertEquals("turn.end", envelope.text("type"))
        assertEquals(outcome.conversationId, envelope.text("conversationId"))
        assertEquals("0", envelope.text("denied"))
        assertEquals("0", envelope.text("executed"))
        assertTrue(envelope["chainOk"].toString().toBoolean())
    }

    private fun engine(
        dataDir: Path,
        device: DevicePort = RecordingDevice(),
        approvals: ApprovalGateway = DenyAllApproval(),
    ): Engine = Engine(
        io = Stdio(),
        hostDevice = device,
        approval = approvals,
        store = ChatStore(dataDir.resolve("conversations.json")),
        recordStore = RecordStore(dataDir.resolve("records.json")),
        config = RuntimeConfig(),
        forceStub = true,
    )
}

/** A device that answers observations and records mutations; it never refuses. */
private class RecordingDevice : DevicePort {
    val taps = mutableListOf<String>()
    val launches = mutableListOf<String>()
    val types = mutableListOf<String>()
    private var observed = 0

    override suspend fun observe(): Observation {
        observed += 1
        return Observation(
            id = "obs-$observed",
            timestamp = 0,
            screenSize = ScreenSize(width = 1280, height = 720),
            app = "test",
            text = "e1 window Test",
            tree = ObservationNode(ref = "e1", type = "window", text = "Test"),
        )
    }

    override suspend fun tap(ref: String?, x: Int?, y: Int?) {
        taps += "${ref.orEmpty()}@${x ?: 0},${y ?: 0}"
    }

    override suspend fun type(text: String, ref: String?) {
        types += text
    }

    override suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int) = Unit

    override suspend fun pressBack() = Unit

    override suspend fun pressHome() = Unit

    override suspend fun launch(packageName: String) {
        launches += packageName
    }

    override suspend fun stop(packageName: String) = Unit

    override suspend fun foreground(): String = "test"

    override suspend fun screenshot(): ByteArray? = null

    override suspend fun apps(): List<InstalledApp> = emptyList()
}
