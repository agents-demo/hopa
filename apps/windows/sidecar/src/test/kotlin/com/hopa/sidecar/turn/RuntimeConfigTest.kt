package com.hopa.sidecar.turn

import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RuntimeConfigTest {
    @Test
    fun replay_and_vision_are_read_from_configure() {
        val config = RuntimeConfig()
        config.update(buildJsonObject {
            put("replay", false)
            put("vision", true)
            put("planFirst", true)
            put("instantCommands", false)
        })

        assertFalse(config.replay)
        assertTrue(config.vision)
        assertTrue(config.planFirst)
        assertFalse(config.instantCommands)
    }

    @Test
    fun missing_flags_keep_the_defaults() {
        val config = RuntimeConfig()
        config.update(buildJsonObject { put("tone", "brief") })

        assertTrue(config.replay)
        assertFalse(config.vision)
        assertFalse(config.planFirst)
        assertTrue(config.instantCommands)
    }
}
