package com.hopa.core.parser

import com.hopa.core.contracts.ErrorCodes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class DecisionParserTest {
    private val parser = DecisionParser()

    @Test
    fun parses_a_contract_action() {
        val outcome = parser.parse(
            """{"schemaVersion":"1","kind":"ui.tap","ref":"e2","timeoutMs":3000}""",
        )
        assertNotNull(outcome.decision)
        assertEquals("ui.tap", outcome.decision?.action?.kind)
        assertEquals("e2", outcome.decision?.action?.ref)
    }

    @Test
    fun rejects_an_unknown_kind() {
        val outcome = parser.parse(
            """{"schemaVersion":"1","kind":"ui.teleport","timeoutMs":3000}""",
        )
        assertNull(outcome.decision)
        assertEquals(ErrorCodes.SCHEMA, outcome.error?.code)
    }

    @Test
    fun rejects_done_with_an_action() {
        val outcome = parser.parse(
            """{"say":"Done.","done":true,"needUser":false,"action":{"kind":"ui.home","timeoutMs":3000}}""",
        )
        assertEquals(ErrorCodes.SCHEMA, outcome.error?.code)
    }

    @Test
    fun rejects_a_question_without_options() {
        val outcome = parser.parse("""{"say":"Which account?","done":false,"needUser":true}""")
        assertEquals(ErrorCodes.SCHEMA, outcome.error?.code)
    }

    @Test
    fun plain_text_is_text() {
        val outcome = parser.parse("The answer is 4.")
        assertEquals("The answer is 4.", outcome.text)
        assertNull(outcome.decision)
    }

    @Test
    fun accepts_a_fenced_action() {
        val outcome = parser.parse("```json\n{\"kind\":\"ui.home\"}\n```")
        assertEquals("ui.home", outcome.decision?.action?.kind)
    }
}
