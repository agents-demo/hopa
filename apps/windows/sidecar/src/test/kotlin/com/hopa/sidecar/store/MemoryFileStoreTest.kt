package com.hopa.sidecar.store

import java.nio.file.Files
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class MemoryFileStoreTest {
    @Test
    fun facts_survive_a_reload_and_keep_their_order() = runBlocking {
        val file = Files.createTempDirectory("hopa-memory").resolve("memory.json")
        val store = MemoryFileStore(file)
        store.add("The car is a blue Volvo")
        store.add("The alarm code is 4321")

        val reloaded = MemoryFileStore(file)
        assertEquals(listOf("The car is a blue Volvo", "The alarm code is 4321"), reloaded.all())
        assertTrue(reloaded.promptText().contains("Things the user asked you to remember:"))
    }

    @Test
    fun duplicate_and_blank_facts_do_not_grow_the_file() = runBlocking {
        val file = Files.createTempDirectory("hopa-memory-two").resolve("memory.json")
        val store = MemoryFileStore(file)
        store.add("one")
        store.add(" one ")
        store.add("")

        assertEquals(listOf("one"), store.all())
    }

    @Test
    fun delete_and_clear_remove_the_facts() = runBlocking {
        val file = Files.createTempDirectory("hopa-memory-three").resolve("memory.json")
        val store = MemoryFileStore(file)
        store.add("one")
        store.add("two")

        store.delete("one")
        assertEquals(listOf("two"), store.all())
        store.clear()
        assertEquals(emptyList<String>(), store.all())
    }
}
