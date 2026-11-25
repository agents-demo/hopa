package com.hopa.sidecar.windows

import com.hopa.decision.graph.HandGraphSource
import com.hopa.contracts.wire.Observation
import com.hopa.contracts.wire.ObservationNode
import com.hopa.contracts.wire.ScreenSize
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test

/** The Windows graph resource is data; it must parse and answer a known goal. */
class WindowsGraphsTest {
    @Test
    fun the_resource_loads_and_has_windows_apps() {
        val graphs = WindowsGraphs.load()

        assertEquals(listOf("Notepad", "File Explorer", "Calculator"), graphs.map { it.name })
        assertEquals("notepad", graphs.first().app)
    }

    @Test
    fun notepad_is_an_anchor_target() {
        val source = HandGraphSource(WindowsGraphs.load())
        val observation = Observation(
            id = "obs",
            timestamp = 0,
            screenSize = ScreenSize(1280, 720),
            tree = ObservationNode(type = "root", text = "Desktop"),
            app = "explorer",
        )

        val target = source.target("open notepad")
        assertNotNull(target)
        assertEquals("notepad", target?.app)
    }
}
