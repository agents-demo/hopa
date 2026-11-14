package com.hopa.sidecar

import com.hopa.core.gate.ApprovalRequest
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Pending approvals on disk. A restart cannot resume the turn, so the state is
 * recorded and denied on the next start, matching the Android rule: survive a
 * rotation, deny on process death, time out after two minutes.
 */
class PendingApprovals(path: Path) {
    private val file: Path = path
    private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }
    private val items: MutableMap<String, JsonObject> = load()

    fun save(id: String, request: ApprovalRequest) {
        items[id] = buildJsonObject {
            put("title", request.title)
            put("body", request.body)
            put("amount", request.amount)
            put("merchant", request.merchant)
            put("consequence", request.consequence)
            put("isPayment", request.isPayment)
            put("action", request.action.kind)
            put("createdAt", System.currentTimeMillis())
        }
        persist()
    }

    fun clear(id: String) {
        if (items.remove(id) != null) {
            persist()
        }
    }

    fun restoreAndDeny(): Int {
        val count = items.size
        items.clear()
        persist()
        return count
    }

    private fun load(): MutableMap<String, JsonObject> {
        if (!Files.exists(file)) {
            return mutableMapOf()
        }
        return runCatching {
            val parsed = json.parseToJsonElement(Files.readString(file)) as JsonObject
            parsed.entries.associateTo(mutableMapOf()) { it.key to (it.value as JsonObject) }
        }.getOrElse { mutableMapOf() }
    }

    private fun persist() {
        runCatching {
            Files.createDirectories(file.parent)
            Files.writeString(file, buildJsonObject { items.forEach { (id, value) -> put(id, value) } }.toString())
        }
    }
}
