package com.hopa.core.records

import com.hopa.core.contracts.RunRecord
import com.hopa.core.json.CanonicalJson
import com.hopa.core.json.HopaJson
import java.security.MessageDigest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject

object RunChain {
    val SEED: String = "sha256:" + digest("")

    fun seal(draft: RunRecordDraft, prevHash: String): RunRecord {
        val unsigned = RunRecord(
            runId = draft.runId,
            step = draft.step,
            timestamp = draft.timestamp,
            traceId = draft.traceId,
            action = draft.action,
            classification = draft.classification,
            approved = draft.approved,
            observationHash = draft.observationHash,
            beforeHash = draft.beforeHash,
            afterHash = draft.afterHash,
            verified = draft.verified,
            executed = draft.executed,
            error = draft.error,
            prevHash = prevHash,
            hash = "",
        )
        val element = HopaJson.element.encodeToJsonElement(RunRecord.serializer(), unsigned).jsonObject
        val withoutHash = JsonObject(element.filterKeys { key -> key != "hash" })
        val hash = "sha256:" + digest(CanonicalJson.encode(withoutHash))
        return unsigned.copy(hash = hash)
    }

    fun verify(records: List<RunRecord>): Boolean {
        var prev = SEED
        for (record in records) {
            if (record.prevHash != prev) {
                return false
            }
            val element = HopaJson.element.encodeToJsonElement(RunRecord.serializer(), record).jsonObject
            val withoutHash = JsonObject(element.filterKeys { key -> key != "hash" })
            val expected = "sha256:" + digest(CanonicalJson.encode(withoutHash))
            if (record.hash != expected) {
                return false
            }
            prev = record.hash
        }
        return true
    }

    private fun digest(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return bytes.joinToString(separator = "") { "%02x".format(it) }
    }
}
