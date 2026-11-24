package com.hopa.sidecar.store

import com.hopa.stores.Skill
import java.nio.file.Files
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class SkillFileStoreTest {
    @Test
    fun skills_survive_a_reload_and_keep_their_order() = runBlocking {
        val file = Files.createTempDirectory("hopa-skills").resolve("skills.json")
        val store = SkillFileStore(file)
        store.add("open my mail", "launch the mail app")
        store.add("bill time", "open the bank")

        val reloaded = SkillFileStore(file)
        assertEquals(
            listOf(
                Skill("open my mail", "launch the mail app"),
                Skill("bill time", "open the bank"),
            ),
            reloaded.all(),
        )
        assertTrue(reloaded.promptText().contains("Triggers the user taught you"))
    }

    @Test
    fun a_trigger_is_replaced_not_duplicated() = runBlocking {
        val file = Files.createTempDirectory("hopa-skills-two").resolve("skills.json")
        val store = SkillFileStore(file)
        store.add("open mail", "old action")
        store.add(" open mail ", "new action")
        store.add("", "ignored")

        assertEquals(listOf(Skill("open mail", "new action")), store.all())
    }

    @Test
    fun delete_and_clear_remove_the_skills() = runBlocking {
        val file = Files.createTempDirectory("hopa-skills-three").resolve("skills.json")
        val store = SkillFileStore(file)
        store.add("one", "action one")
        store.add("two", "action two")

        store.delete("one")
        assertEquals(listOf(Skill("two", "action two")), store.all())
        store.clear()
        assertEquals(emptyList<Skill>(), store.all())
    }
}
