package com.hopa.data.memory

import com.hopa.data.database.dao.MemoryDao
import com.hopa.data.database.entity.MemoryFactEntity

class RoomMemoryStore(
    private val dao: MemoryDao,
) : MemoryStore {
    override suspend fun all(): List<String> = dao.all().map { it.text }

    override suspend fun add(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) {
            return
        }
        dao.insert(MemoryFactEntity(text = trimmed, createdAt = System.currentTimeMillis()))
    }

    override suspend fun delete(text: String) {
        dao.delete(text)
    }

    override suspend fun clear() {
        dao.deleteAll()
    }

    override suspend fun promptText(): String {
        val facts = all()
        if (facts.isEmpty()) {
            return ""
        }
        return "Things the user asked you to remember:\n" +
            facts.joinToString("\n") { "- $it" }
    }
}
