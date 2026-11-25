package com.hopa.sidecar.protocol

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The builders and the committed goldens are one contract.
 *
 * The schema says what a frame family may contain; these frames say what the
 * current build actually emits. A field that moves, a family that is renamed
 * or a required value that disappears fails here before the host sees it.
 */
class ProtocolGoldenTest {
    private val golden: List<JsonObject> = File(GOLDEN)
        .readLines()
        .filter { it.isNotBlank() }
        .map { Json.parseToJsonElement(it) as JsonObject }

    @Test
    fun the_builders_match_the_committed_golden_frames() {
        val built = listOf(
            Protocol.ready(),
            Protocol.log("ready"),
            Protocol.configured("r-1", bridge = false, model = "on-device"),
            Protocol.session("t", "r"),
            Protocol.deviceRequest("d-1", "observe") {},
            Protocol.browserRequest("b-1", "open") {},
            Protocol.taskRefused("t-1", "task.start", "unsupported"),
            Protocol.backendPair(true),
            Protocol.turnEnd("r-1", "c-1", "T", "A", emptyList(), chainOk = true),
        )

        assertEquals(golden.size, built.size, "the golden file has a different frame count")
        built.zip(golden).forEachIndexed { index, (actual, expected) ->
            assertEquals(expected, actual, "frame $index (${actual["type"]}) drifted from the golden")
        }
    }

    @Test
    fun every_golden_frame_has_a_type() {
        assertTrue(golden.all { it["type"] != null }, "a golden frame has no type")
        assertTrue(
            golden.map { it["type"].toString() }.toSet().size == golden.size,
            "the golden file repeats a family",
        )
    }

    private companion object {
        /** From `apps/windows/sidecar` (the test task's working directory). */
        const val GOLDEN = "../../../spec/protocol/golden.ndjson"
    }
}
