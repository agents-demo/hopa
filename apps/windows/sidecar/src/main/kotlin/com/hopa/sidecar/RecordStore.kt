package com.hopa.sidecar

import com.hopa.core.contracts.RunRecord
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.put

/** Run records per turn, appended to one JSON file so a restart keeps them. */
class RecordStore(path: Path) {
    private val file: Path = path
    private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }
    private var turns: MutableList<JsonObject> = load()

    fun append(conversationId: String, runId: String, records: List<RunRecord>) {
        if (records.isEmpty()) {
            return
        }
        turns.add(
            buildJsonObject {
                put("conversationId", conversationId)
                put("runId", runId)
                put("createdAt", System.currentTimeMillis())
                put("records", buildJsonArray {
                    records.forEach { add(json.encodeToJsonElement(RunRecord.serializer(), it)) }
                })
            },
        )
        persist()
    }

    fun count(): Int = turns.size

    private fun load(): MutableList<JsonObject> {
        if (!Files.exists(file)) {
            return mutableListOf()
        }
        return runCatching {
            (json.parseToJsonElement(Files.readString(file)) as JsonArray)
                .mapNotNull { it as? JsonObject }
                .toMutableList()
        }.getOrElse { mutableListOf() }
    }

    private fun persist() {
        runCatching {
            Files.createDirectories(file.parent)
            Files.writeString(file, buildJsonArray { turns.forEach { add(it) } }.toString())
        }
    }
}
