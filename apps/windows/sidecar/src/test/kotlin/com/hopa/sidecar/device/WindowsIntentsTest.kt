package com.hopa.sidecar.device

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class WindowsIntentsTest {
    private val intents = WindowsIntents()

    @Test
    fun aliases_are_case_insensitive() {
        assertEquals("ms-settings:network-wifi", intents.resolve("WiFi"))
        assertEquals("ms-settings:network-wifi", intents.resolve(" wifi "))
    }

    @Test
    fun settings_pages_pass_through() {
        assertEquals("ms-settings:display", intents.resolve("ms-settings:display"))
    }

    @Test
    fun web_urls_pass_through() {
        assertEquals("https://example.com", intents.resolve("https://example.com"))
    }

    @Test
    fun package_names_are_not_aliases() {
        assertNull(intents.resolve("com.android.settings"))
    }

    @Test
    fun unknown_words_are_not_rewritten() {
        assertNull(intents.resolve("notepad"))
        assertNull(intents.resolve(""))
    }
}
