package com.hopa.data.sessions

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class DropLastExchangeTest {
    @Test
    fun the_last_user_and_assistant_turn_are_removed() = runBlocking {
        val store = InMemoryConversationStore()
        val chat = store.create()
        store.append(chat.id, ChatMessage("m1", "user", "first", 1))
        store.append(chat.id, ChatMessage("m2", "assistant", "one", 2))
        store.append(chat.id, ChatMessage("m3", "user", "second", 3))
        store.append(chat.id, ChatMessage("m4", "assistant", "two", 4))

        store.dropLastExchange(chat.id)

        val messages = store.allWithDeleted().single { it.id == chat.id }.messages
        assertEquals(listOf("m1", "m2"), messages.map { it.id })
    }
}
