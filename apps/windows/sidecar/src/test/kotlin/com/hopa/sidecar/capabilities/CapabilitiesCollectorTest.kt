package com.hopa.sidecar.capabilities

import com.hopa.agent.recipe.RecipeStore
import com.hopa.sidecar.store.MemoryFileStore
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.store.SkillFileStore
import com.hopa.sidecar.turn.RuntimeConfig
import java.nio.file.Files
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CapabilitiesCollectorTest {
    @Test
    fun the_summary_reads_the_real_stores() = runBlocking {
        val data = Files.createTempDirectory("hopa-capabilities")
        val memory = MemoryFileStore(data.resolve("memory.json"))
        val skills = SkillFileStore(data.resolve("skills.json"))
        memory.add("blue car")
        skills.add("open mail", "launch mail")

        val summary = CapabilitiesCollector(
            config = RuntimeConfig(),
            memory = memory,
            skills = skills,
            recipes = RecipeStore(data.resolve("recipes.txt").toFile()),
            records = RecordStore(data.resolve("records.json")),
        ).collect()

        assertEquals("windows", summary.platform)
        assertEquals("everyday", summary.profile)
        assertFalse(summary.modelReady)
        assertEquals(1, summary.memory)
        assertEquals(1, summary.skills)
        assertEquals(0, summary.runs)
        assertTrue(summary.windowsApps >= 0)
    }
}
