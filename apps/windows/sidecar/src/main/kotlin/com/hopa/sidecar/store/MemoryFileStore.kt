package com.hopa.sidecar.store

import com.hopa.stores.MemoryStore
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/**
 * The Windows memory file: a JSON array of facts, written whole and read on
 * demand. It implements the same [MemoryStore] the Android app uses, so the
 * prompt text and the screen contract stay identical.
 */
internal class MemoryFileStore(private val file: Path) : MemoryStore {
    private val gate = Mutex()

    override suspend fun all(): List<String> = gate.withLock { read() }

    override suspend fun add(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) {
            return
        }
        gate.withLock {
            val facts = read().toMutableList()
            if (facts.none { it == trimmed }) {
                facts += trimmed
                write(facts)
            }
        }
    }

    override suspend fun delete(text: String) {
        val trimmed = text.trim()
        gate.withLock {
            write(read().filterNot { it == trimmed })
        }
    }

    override suspend fun clear() {
        gate.withLock {
            runCatching { Files.deleteIfExists(file) }
        }
    }

    override suspend fun promptText(): String {
        val facts = all()
        if (facts.isEmpty()) {
            return ""
        }
        return "Things the user asked you to remember:\n" +
            facts.joinToString("\n") { "- $it" }
    }

    private fun read(): List<String> {
        if (!Files.exists(file)) {
            return emptyList()
        }
        return runCatching {
            val array = Json.parseToJsonElement(Files.readString(file)) as JsonArray
            array.mapNotNull { it.jsonPrimitive.contentOrNull }
        }.getOrDefault(emptyList())
    }

    private fun write(facts: List<String>) {
        file.parent?.let { Files.createDirectories(it) }
        Files.writeString(file, JsonArray(facts.map(::JsonPrimitive)).toString())
    }
}
