package com.hopa.data.memory

/** Facts the user asked HOPA to keep; they ride along in the system prompt. */
interface MemoryStore {
    suspend fun all(): List<String>

    suspend fun add(text: String)

    suspend fun delete(text: String)

    suspend fun clear()

    suspend fun promptText(): String
}
