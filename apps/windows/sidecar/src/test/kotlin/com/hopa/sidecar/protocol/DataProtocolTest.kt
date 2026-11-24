package com.hopa.sidecar.protocol

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.handler.MemoryHandler
import com.hopa.sidecar.protocol.handler.ProfilesHandler
import com.hopa.sidecar.protocol.handler.SkillHandler
import com.hopa.sidecar.store.MemoryFileStore
import com.hopa.sidecar.store.SkillFileStore
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.file.Files
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** The memory/skill families are additive v1 messages with one reply per line. */
class DataProtocolTest {
    @Test
    fun memory_and_skill_lists_carry_their_items() {
        val memory = Protocol.memoryList("m-1", listOf("blue car", "alarm 4321"))
        assertEquals("memory.list", memory.text("type"))
        assertEquals("m-1", memory.text("id"))
        assertEquals("true", memory["ok"].toString())
        assertTrue(memory["items"].toString().contains("blue car"))

        val skills = Protocol.skillList("s-1", listOf(com.hopa.stores.Skill("open mail", "launch mail")))
        assertEquals("skills.list", skills.text("type"))
        assertTrue(skills["items"].toString().contains("\"trigger\":\"open mail\""))
    }

    @Test
    fun a_bad_request_is_an_error_line() {
        val error = Protocol.dataError("m-2", "memory", "E_SCHEMA", "text is empty")
        assertEquals("memory.error", error.text("type"))
        assertEquals("false", error["ok"].toString())
        assertEquals("E_SCHEMA", error.text("code"))
    }

    @Test
    fun history_usage_and_recipes_have_stable_shapes() {
        val history = Protocol.historyList("h-1", listOf(
            com.hopa.sidecar.store.HistoryEntry("c1", "Say hello", "run-1", 123, 2, 1, 1),
        ))
        assertEquals("history.list", history.text("type"))
        assertTrue(history["items"].toString().contains("\"steps\":2"))

        val usage = Protocol.usageSummary("u-1", com.hopa.sidecar.store.UsageStats(
            total = 2, executed = 1, failed = 1, payments = 0, lastSevenDays = 2,
            topActions = listOf("ui.tap" to 1),
        ))
        assertEquals("usage.summary", usage.text("type"))
        assertTrue(usage["topActions"].toString().contains("\"kind\":\"ui.tap\""))

        val recipes = Protocol.recipeList("r-1", listOf(
            com.hopa.agent.recipe.Recipe(
                goal = "open mail",
                steps = emptyList(),
                at = 123,
                screenHash = "sha256:before",
                endHash = "sha256:after",
            ),
        ))
        assertEquals("recipes.list", recipes.text("type"))
        assertTrue(recipes["items"].toString().contains("\"goal\":\"open mail\""))
    }

    @Test
    fun the_profile_handler_lists_and_selects_a_shared_profile() {
        val config = com.hopa.sidecar.turn.RuntimeConfig()
        val handler = ProfilesHandler(Stdio(), config)

        val listed = capture { handler.handle("profiles.list", message("profiles.list", "id" to "p-1")) }
        val first = listed.single()
        assertEquals("profiles.list", first.text("type"))
        assertEquals("everyday", first.text("selected"))
        assertTrue(first["items"].toString().contains("\"key\":\"power\""))

        val selected = capture {
            handler.handle("profiles.select", message("profiles.select", "id" to "p-2", "profile" to "power"))
        }
        assertEquals("power", selected.single().text("selected"))

        val refused = capture {
            handler.handle("profiles.select", message("profiles.select", "id" to "p-3", "profile" to "nope"))
        }
        assertEquals("profiles.error", refused.single().text("type"))
    }

    @Test
    fun the_memory_handler_adds_deletes_and_returns_the_new_list() {
        val file = Files.createTempDirectory("hopa-memory-handler").resolve("memory.json")
        val handler = MemoryHandler(Stdio(), MemoryFileStore(file))

        val added = capture { handler.handle("memory.add", message("memory.add", "id" to "m-1", "text" to "blue car")) }
        assertEquals("memory.list", added.last().text("type"))

        val listed = capture { handler.handle("memory.list", message("memory.list", "id" to "m-2")) }
        assertTrue(listed.last()["items"].toString().contains("blue car"))

        val deleted = capture { handler.handle("memory.delete", message("memory.delete", "id" to "m-3", "text" to "blue car")) }
        assertEquals("[]", deleted.last()["items"].toString())
    }

    @Test
    fun a_malformed_memory_add_is_refused_without_writing() {
        val file = Files.createTempDirectory("hopa-memory-bad").resolve("memory.json")
        val handler = MemoryHandler(Stdio(), MemoryFileStore(file))

        val reply = capture { handler.handle("memory.add", message("memory.add", "id" to "m-1", "text" to "")) }
        assertEquals("memory.error", reply.single().text("type"))
        assertEquals("E_SCHEMA", reply.single().text("code"))
        assertTrue(!Files.exists(file))
    }

    @Test
    fun the_skill_handler_round_trips_a_pair() {
        val file = Files.createTempDirectory("hopa-skill-handler").resolve("skills.json")
        val handler = SkillHandler(Stdio(), SkillFileStore(file))

        val added = capture {
            handler.handle(
                "skills.add",
                message("skills.add", "id" to "s-1", "trigger" to "open mail", "action" to "launch mail"),
            )
        }
        assertEquals("skills.list", added.single().text("type"))
        assertTrue(added.single()["items"].toString().contains("\"action\":\"launch mail\""))

        val bad = capture {
            handler.handle("skills.add", message("skills.add", "id" to "s-2", "trigger" to "x", "action" to ""))
        }
        assertEquals("skills.error", bad.single().text("type"))
    }

    private fun message(type: String, vararg pairs: Pair<String, String>): JsonObject =
        buildJsonObject {
            put("type", type)
            pairs.forEach { (key, value) -> put(key, value) }
        }

    private fun capture(block: () -> Unit): List<JsonObject> {
        val original = System.out
        val buffer = ByteArrayOutputStream()
        System.setOut(PrintStream(buffer, true, "UTF-8"))
        try {
            block()
        } finally {
            System.setOut(original)
        }

        return buffer.toString(Charsets.UTF_8)
            .lineSequence()
            .filter { it.isNotBlank() }
            .map { Json.parseToJsonElement(it) as JsonObject }
            .toList()
    }
}
