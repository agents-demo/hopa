package com.hopa.sidecar.store

import com.hopa.stores.Skill
import com.hopa.stores.SkillStore
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * The Windows skill file: trigger → action pairs in a JSON array, using the
 * same [SkillStore] contract as the phone. The prompt text must stay identical
 * so the model sees the same instruction on either client.
 */
internal class SkillFileStore(private val file: Path) : SkillStore {
    private val gate = Mutex()

    override suspend fun all(): List<Skill> = gate.withLock { read() }

    override suspend fun add(trigger: String, action: String) {
        val key = trigger.trim()
        val value = action.trim()
        if (key.isEmpty() || value.isEmpty()) {
            return
        }
        gate.withLock {
            val skills = read().filterNot { it.trigger == key }.toMutableList()
            skills += Skill(trigger = key, action = value)
            write(skills)
        }
    }

    override suspend fun delete(trigger: String) {
        val key = trigger.trim()
        gate.withLock {
            write(read().filterNot { it.trigger == key })
        }
    }

    override suspend fun clear() {
        gate.withLock {
            runCatching { Files.deleteIfExists(file) }
        }
    }

    override suspend fun promptText(): String {
        val skills = all()
        if (skills.isEmpty()) {
            return ""
        }
        return "Triggers the user taught you (use the action when the goal matches):\n" +
            skills.joinToString("\n") { "- \"${it.trigger}\" → ${it.action}" }
    }

    private fun read(): List<Skill> {
        if (!Files.exists(file)) {
            return emptyList()
        }
        return runCatching {
            val array = Json.parseToJsonElement(Files.readString(file)) as JsonArray
            array.mapNotNull { element ->
                val row = element.jsonObject
                val trigger = row["trigger"]?.jsonPrimitive?.contentOrNull.orEmpty()
                val action = row["action"]?.jsonPrimitive?.contentOrNull.orEmpty()
                if (trigger.isBlank() || action.isBlank()) {
                    null
                } else {
                    Skill(trigger = trigger, action = action)
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun write(skills: List<Skill>) {
        file.parent?.let { Files.createDirectories(it) }
        val array = buildJsonArray {
            skills.forEach { skill ->
                add(buildJsonObject {
                    put("trigger", skill.trigger)
                    put("action", skill.action)
                })
            }
        }
        Files.writeString(file, array.toString())
    }
}
