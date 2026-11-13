package com.hopa.core.contracts

import com.hopa.core.json.HopaJson
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * The contract requires `approved` and `error` to be present, with `null` when
 * they do not apply, while the shared `HopaJson` omits nulls. This serializer
 * writes the record exactly as `contracts/schemas/run-record.schema.json` says.
 */
internal object RunRecordSerializer : KSerializer<RunRecord> {
    override val descriptor: SerialDescriptor =
        buildClassSerialDescriptor("com.hopa.core.contracts.RunRecord")

    override fun serialize(encoder: Encoder, value: RunRecord) {
        val json = encoder as? JsonEncoder ?: error("RunRecord is JSON only")
        json.encodeJsonElement(
            buildJsonObject {
                put("schemaVersion", value.schemaVersion)
                put("runId", value.runId)
                put("step", value.step)
                value.timestamp?.let { put("timestamp", it) }
                put("traceId", value.traceId)
                put(
                    "action",
                    HopaJson.element.encodeToJsonElement(Action.serializer(), value.action),
                )
                put("classification", value.classification)
                put("approved", value.approved?.let { JsonPrimitive(it) } ?: JsonNull)
                put("observationHash", value.observationHash)
                value.beforeHash?.let { put("beforeHash", it) }
                value.afterHash?.let { put("afterHash", it) }
                put("verified", value.verified)
                put("executed", value.executed)
                put("error", value.error?.let { JsonPrimitive(it) } ?: JsonNull)
                put("prevHash", value.prevHash)
                put("hash", value.hash)
            },
        )
    }

    override fun deserialize(decoder: Decoder): RunRecord {
        val json = decoder as? JsonDecoder ?: error("RunRecord is JSON only")
        val payload = json.decodeJsonElement().jsonObject
        fun text(name: String): String? =
            (payload[name] as? JsonPrimitive)?.takeUnless { it is JsonNull }?.contentOrNull
        fun flag(name: String): Boolean? =
            (payload[name] as? JsonPrimitive)?.takeUnless { it is JsonNull }?.booleanOrNull
        return RunRecord(
            schemaVersion = text("schemaVersion") ?: "1",
            runId = text("runId").orEmpty(),
            step = text("step")?.toIntOrNull() ?: 0,
            timestamp = text("timestamp"),
            traceId = text("traceId").orEmpty(),
            action = HopaJson.element.decodeFromJsonElement(
                Action.serializer(),
                requireNotNull(payload["action"]) { "run record without an action" },
            ),
            classification = text("classification").orEmpty(),
            approved = flag("approved"),
            observationHash = text("observationHash").orEmpty(),
            beforeHash = text("beforeHash"),
            afterHash = text("afterHash"),
            verified = flag("verified") ?: false,
            executed = flag("executed") ?: false,
            error = text("error"),
            prevHash = text("prevHash").orEmpty(),
            hash = text("hash").orEmpty(),
        )
    }
}
