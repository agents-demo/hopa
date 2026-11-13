package com.hopa.app.feature.sync

import com.hopa.capabilities.bridge.ChatTransport
import com.hopa.data.sessions.ChatMessage
import com.hopa.data.sessions.Conversation
import com.hopa.data.sessions.InMemoryConversationStore
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatSyncTest {
    @Test
    fun a_remote_session_is_adopted() = runBlocking {
        val store = InMemoryConversationStore()
        val remote = sessionJson("s-1", "Remote", listOf("hello" to 10L))
        val report = ChatSync(store, FakeTransport(snapshot(remote))).run()

        assertEquals(1, report.adopted)
        val session = store.allWithDeleted().single { it.id == "s-1" }
        assertEquals("Remote", session.title)
        assertEquals("hello", session.messages.single().text)
    }

    @Test
    fun a_session_missing_after_a_push_is_tombstoned() = runBlocking {
        val store = InMemoryConversationStore()
        store.adopt(
            Conversation(
                id = "s-2",
                title = "Local",
                messages = listOf(ChatMessage("m1", "user", "hi", 1)),
                updatedAt = 1,
            ),
        )
        val report = ChatSync(store, FakeTransport(snapshot())).run()

        assertEquals(1, report.tombstoned)
        assertTrue(store.allWithDeleted().single { it.id == "s-2" }.deletedAt > 0)
    }

    @Test
    fun a_remote_copy_does_not_resurrect_a_local_deletion() = runBlocking {
        val store = InMemoryConversationStore()
        store.adopt(
            Conversation(
                id = "s-3",
                title = "Local",
                messages = listOf(ChatMessage("m1", "user", "hi", 1)),
                updatedAt = 1,
                deletedAt = 5,
            ),
        )
        ChatSync(store, FakeTransport(snapshot(sessionJson("s-3", "Local", listOf("hi" to 1))))).run()

        assertTrue(store.allWithDeleted().single { it.id == "s-3" }.deletedAt > 0)
    }

    @Test
    fun a_failed_push_falls_back_to_a_pull_and_keeps_local_rows() = runBlocking {
        val store = InMemoryConversationStore()
        store.adopt(
            Conversation(
                id = "s-4",
                title = "Local",
                messages = listOf(ChatMessage("m1", "user", "hi", 1)),
                updatedAt = 1,
            ),
        )
        val transport = FakeTransport(snapshot(), failPush = true)
        val report = ChatSync(store, transport).run()

        assertTrue(report.pulledFallback)
        assertEquals(1, transport.pulls)
        assertEquals(0, report.tombstoned)
        assertEquals(0, store.allWithDeleted().single { it.id == "s-4" }.deletedAt)
    }

    @Test
    fun an_empty_draft_is_neither_pushed_nor_deleted() = runBlocking {
        val store = InMemoryConversationStore()
        val draft = store.create()
        val transport = FakeTransport(snapshot())
        val report = ChatSync(store, transport).run()

        assertEquals(0, transport.pushed.size)
        assertEquals(0, report.tombstoned)
        assertEquals(0, store.allWithDeleted().single { it.id == draft.id }.deletedAt)
    }

    @Test
    fun the_wire_json_round_trips() {
        val session = Conversation(
            id = "s-5",
            title = "Title",
            messages = listOf(ChatMessage("m1", "user", "hi", 7)),
            updatedAt = 9,
            pinned = true,
        )
        val decoded = ChatSyncJson.decode(ChatSyncJson.encode(session))

        assertEquals("s-5", decoded.id)
        assertEquals("Title", decoded.title)
        assertEquals(9, decoded.updatedAt)
        assertEquals("hi", decoded.messages.single().text)
        assertEquals(7, decoded.messages.single().timestamp)
    }

    private class FakeTransport(
        private val snapshot: JsonObject,
        private val failPush: Boolean = false,
    ) : ChatTransport {
        var pushed: JsonArray = JsonArray(emptyList())
        var pulls = 0

        override suspend fun push(sessions: JsonArray): JsonObject {
            if (failPush) {
                throw IllegalStateException("bridge unreachable")
            }
            pushed = sessions
            return snapshot
        }

        override suspend fun pull(): JsonObject {
            pulls += 1
            return snapshot
        }
    }

    private fun snapshot(vararg sessions: JsonObject): JsonObject = buildJsonObject {
        put("rev", 1)
        put(
            "sessions",
            buildJsonArray { sessions.forEach { add(it) } },
        )
    }

    private fun sessionJson(
        id: String,
        title: String,
        messages: List<Pair<String, Long>>,
    ): JsonObject = buildJsonObject {
        put("id", id)
        put("title", title)
        put("titleAt", messages.lastOrNull()?.second ?: 0)
        put("created", messages.firstOrNull()?.second ?: 0)
        put("updated", messages.lastOrNull()?.second ?: 0)
        put("deletedAt", 0)
        put(
            "turns",
            buildJsonArray {
                messages.forEachIndexed { index, (text, at) ->
                    add(
                        buildJsonObject {
                            put("id", "$id-t$index")
                            put("role", "user")
                            put("text", text)
                            put("at", at)
                        },
                    )
                }
            },
        )
    }
}
