package com.hopa.core.prompt

import com.hopa.prompt.PROMPT_RULES
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemPromptTest {
    @Test
    fun the_prompt_carries_every_shared_rule() {
        val prompt = SystemPromptBuilder().build()
        for (rule in PROMPT_RULES) {
            for (phrase in rule.phrases) {
                assertTrue("${rule.id} is missing: $phrase", prompt.contains(phrase))
            }
        }
    }

    @Test
    fun the_web_rule_follows_the_capability() {
        val withWeb = SystemPromptBuilder().build(webAvailable = true)
        val withoutWeb = SystemPromptBuilder().build(webAvailable = false)
        assertTrue(withWeb.contains("web.navigate, web.read, web.click and web.type exist"))
        assertTrue(withoutWeb.contains("There is no web capability"))
    }

    @Test
    fun a_missing_surface_forbids_screen_actions() {
        val prompt = SystemPromptBuilder().build(surfaceAvailable = false)
        assertTrue(prompt.contains("No screen is available"))
    }
}
