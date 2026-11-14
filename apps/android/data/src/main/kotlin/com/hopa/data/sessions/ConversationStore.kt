package com.hopa.data.sessions

interface ConversationStore {
    suspend fun all(): List<Conversation>

    /** Live and tombstoned rows; sync needs the tombstones. */
    suspend fun allWithDeleted(): List<Conversation>

    /** Copy a session from a merged snapshot, appending only unknown turns. */
    suspend fun adopt(session: Conversation)

    /** Undo: drop the last user message and the answer that followed it. */
    suspend fun dropLastExchange(id: String)

    suspend fun search(query: String): List<Conversation>

    suspend fun create(): Conversation

    suspend fun append(id: String, message: ChatMessage)

    suspend fun rename(id: String, title: String)

    suspend fun delete(id: String)

    suspend fun deleteAll()

    suspend fun restore(id: String)

    suspend fun setPinned(id: String, pinned: Boolean)

    suspend fun archive(id: String)
}
