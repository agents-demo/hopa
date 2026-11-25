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
    fun step_source_is_auto_or_model_only() {
        val auto = RuntimeConfig()
        auto.update(buildJsonObject { put("stepSource", "model") })
        assertTrue(auto.stepSource == "model")

        val anchors = RuntimeConfig()
        anchors.update(buildJsonObject { put("stepSource", "anchors") })
        assertTrue(anchors.stepSource == "anchors")

        val model = RuntimeConfig()
        model.update(buildJsonObject { put("stepSource", "graph") })
        assertTrue(model.stepSource == "auto")
    }

    @Test
    fun fallback_needs_consent_a_local_provider_and_a_complete_api() {
        val config = RuntimeConfig()
        config.update(buildJsonObject {
            put("modelProvider", "on-device")
            put("cloudFallback", true)
            put("fallbackProvider", "openai")
            put("fallbackBaseUrl", "https://api.example.com/v1")
            put("fallbackModelName", "m")
            put("fallbackModelKey", "sk-test")
        })
        assertTrue(config.hasFallback)

        val noConsent = RuntimeConfig()
        noConsent.update(buildJsonObject {
            put("modelProvider", "on-device")
            put("cloudFallback", false)
            put("fallbackBaseUrl", "https://api.example.com/v1")
            put("fallbackModelName", "m")
            put("fallbackModelKey", "sk-test")
        })
        assertFalse(noConsent.hasFallback)

        val noKey = RuntimeConfig()
        noKey.update(buildJsonObject {
            put("modelProvider", "on-device")
            put("cloudFallback", true)
            put("fallbackBaseUrl", "https://api.example.com/v1")
            put("fallbackModelName", "m")
        })
        assertFalse(noKey.hasFallback)

        val cloudPrimary = RuntimeConfig()
        cloudPrimary.update(buildJsonObject {
            put("modelProvider", "openai")
            put("cloudFallback", true)
            put("fallbackBaseUrl", "https://api.example.com/v1")
            put("fallbackModelName", "m")
            put("fallbackModelKey", "sk-test")
        })
        assertFalse(cloudPrimary.hasFallback)
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
