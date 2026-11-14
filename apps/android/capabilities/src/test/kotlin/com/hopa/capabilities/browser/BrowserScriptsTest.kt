package com.hopa.capabilities.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BrowserScriptsTest {
    @Test
    fun selectors_are_escaped_as_javascript_strings() {
        val script = BrowserScripts.click("a[title=\"x\"]\\n")
        assertTrue(script.contains("\"a[title=\\\"x\\\"]\\\\n\""))
    }

    @Test
    fun typing_escapes_text_and_quotes() {
        val script = BrowserScripts.type("#q", "he said \"hi\"\n")
        assertTrue(script.contains("\"he said \\\"hi\\\"\\n\""))
        assertTrue(script.contains("dispatchEvent(new Event('input'"))
    }

    @Test
    fun the_read_cap_is_twenty_thousand_characters() {
        assertEquals(20_000, BrowserScripts.cap("x".repeat(25_000)).length)
    }

    @Test
    fun a_short_read_is_untouched() {
        assertEquals("hello", BrowserScripts.cap("hello"))
    }
}
