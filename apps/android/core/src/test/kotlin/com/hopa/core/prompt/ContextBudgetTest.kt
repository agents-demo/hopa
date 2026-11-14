package com.hopa.core.prompt

import com.hopa.core.model.ModelMessage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContextBudgetTest {
    private val budget = ContextBudget()

    @Test
    fun an_empty_history_stays_empty() {
        assertTrue(budget.fit(emptyList()).isEmpty())
    }

    @Test
    fun old_lines_are_trimmed_to_400_chars() {
        val history = List(10) { ModelMessage("user", "x".repeat(1_000)) }
        val fitted = budget.fit(history)

        assertEquals(10, fitted.size)
        fitted.take(4).forEach { assertEquals(400, it.content.length) }
    }

    @Test
    fun the_last_six_messages_are_not_trimmed() {
        val history = List(10) { ModelMessage("user", "x".repeat(1_000)) }
        val fitted = budget.fit(history)

        fitted.takeLast(6).forEach { assertEquals(1_000, it.content.length) }
    }

    @Test
    fun the_oldest_messages_are_dropped_above_the_cap() {
        val history = List(60) { index -> ModelMessage("user", "message $index " + "x".repeat(1_000)) }
        val fitted = budget.fit(history)

        assertTrue(fitted.sumOf { it.content.length } <= 24_000)
        assertTrue(fitted.isNotEmpty())
        assertEquals(history.last(), fitted.last())
    }
}
