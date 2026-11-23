package com.hopa.sidecar.protocol

import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.wire.RunRecord
import com.hopa.contracts.chat.Attachment
import com.hopa.contracts.chat.Conversation
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import com.hopa.sidecar.turn.TurnOutcome
import com.hopa.sidecar.store.HandoffTask

/** The NDJSON messages between the .NET host and this sidecar. */
object Protocol {
    const val VERSION = 1
    private val json = Json { encodeDefaults = true }

    fun ready(): JsonObject = buildJsonObject {
        put("type", "ready")
        put("version", VERSION)
    }

    fun log(text: String): JsonObject = buildJsonObject {
        put("type", "log")
        put("text", text)
    }

    fun turnEnd(
        id: String,
        conversationId: String,
        title: String,
        answer: String,
        steps: List<RunRecord>,
        chainOk: Boolean,
    ): JsonObject =
        buildJsonObject {
            put("type", "turn.end")
            put("id", id)
            put("conversationId", conversationId)
            put("title", title)
            put("answer", answer)
            put("chainOk", chainOk)
            put("steps", buildJsonArray {
                steps.forEach { add(json.encodeToJsonElement(RunRecord.serializer(), it)) }
            })
        }

    /** One action finished; the rail can fill before the turn ends. */
    fun step(
        turnId: String,
        index: Int,
        record: RunRecord,
        at: Long,
        durationMs: Long,
    ): JsonObject = buildJsonObject {
        put("type", "step")
        put("id", turnId)
        put("index", index)
        put("action", record.action.kind)
        put("classification", record.classification)
        put("tier", record.tier)
        put("approved", record.approved)
        // P4: who answered, so the rail can name the phone before turn.end.
        record.approver?.let { approver ->
            put("approver", buildJsonObject {
                put("device", approver.device)
                put("at", approver.at)
            })
        }
        put("executed", record.executed)
        put("verified", record.verified)
        put("error", record.error)
        put("at", at)
        put("durationMs", durationMs)
    }

    /** `--turn` prints one of these on stdout; there is no host to talk to. */
    fun headlessTurn(id: String, outcome: TurnOutcome): JsonObject = buildJsonObject {
        put("type", "turn.end")
        put("id", id)
        put("conversationId", outcome.conversationId)
        put("title", outcome.title)
        put("answer", outcome.answer)
        put("chainOk", outcome.chainOk)
        put("error", outcome.error)
        put("records", outcome.records.size)
        put("executed", outcome.records.count { it.executed })
        put("denied", outcome.records.count { it.approved == false && !it.executed })
        put("steps", buildJsonArray {
            outcome.records.forEach {
                add(json.encodeToJsonElement(RunRecord.serializer(), it))
            }
        })
        put("narration", buildJsonArray {
            outcome.narration.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
        })
    }

    /** v1 freezes the task shapes but refuses them until P4. */
    fun taskRefused(id: String, type: String, error: String): JsonObject = buildJsonObject {
        put("type", "task.error")
        put("id", id)
        put("request", type)
        put("ok", false)
        put("code", "E_UNSUPPORTED")
        put("error", error)
    }

    /** P4: the frozen task shape from protocol.md, echoed on every task reply. */
    fun task(id: String, task: HandoffTask, type: String = "task.start"): JsonObject =
        buildJsonObject {
            put("type", type)
            put("id", id)
            put("ok", true)
            put("task", taskJson(task))
        }

    fun taskList(id: String, tasks: List<HandoffTask>): JsonObject = buildJsonObject {
        put("type", "task.list")
        put("id", id)
        put("ok", true)
        put("tasks", buildJsonArray { tasks.forEach { add(taskJson(it)) } })
    }

    fun taskError(id: String, request: String, code: String, error: String): JsonObject =
        buildJsonObject {
            put("type", "task.error")
            put("id", id)
            put("request", request)
            put("ok", false)
            put("code", code)
            put("error", error)
        }

    private fun taskJson(task: HandoffTask): JsonObject = buildJsonObject {
        put("id", task.id)
        put("goal", task.goal)
        put("state", task.state)
        put("from", task.from)
        task.to?.let { put("to", it) }
        put("events", buildJsonArray {
            task.events.forEach { event ->
                add(buildJsonObject {
                    put("index", event.index)
                    put("type", event.type)
                    put("from", event.from)
                    put("at", event.at)
                })
            }
        })
        put("postconditions", buildJsonArray {
            task.postconditions.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
        })
        task.approver?.let {
            put("approver", buildJsonObject {
                put("device", it.device)
                put("at", it.at)
            })
        }
        task.error?.let { put("error", it) }
    }

    fun approvalRequest(id: String, request: ApprovalRequest): JsonObject = buildJsonObject {
        put("type", "approval.request")
        put("id", id)
        put("title", request.title)
        put("body", request.body)
        put("amount", request.amount)
        put("merchant", request.merchant)
        put("consequence", request.consequence)
        put("isPayment", request.isPayment)
        put("action", request.action.kind)
    }

    fun conversationList(id: String, items: List<Conversation>): JsonObject = buildJsonObject {
        put("type", "conversations.list")
        put("id", id)
        put("items", buildJsonArray {
            items.forEach { add(json.encodeToJsonElement(Conversation.serializer(), it)) }
        })
    }

    fun conversationOpened(id: String, conversation: Conversation?): JsonObject = buildJsonObject {
        put("type", "conversation.history")
        put("id", id)
        if (conversation != null) {
            put("conversation", json.encodeToJsonElement(Conversation.serializer(), conversation))
        }
    }

    fun configured(id: String, bridge: Boolean, model: String): JsonObject = buildJsonObject {
        put("type", "configured")
        put("id", id)
        put("bridge", bridge)
        put("model", model)
    }

    /** The sidecar rotated the pair; the host persists it (never logged). */
    fun session(token: String, refresh: String): JsonObject = buildJsonObject {
        put("type", "session")
        put("token", token)
        put("refresh", refresh)
    }

    fun conversationDeleted(id: String, ok: Boolean): JsonObject = buildJsonObject {
        put("type", "conversation.deleted")
        put("id", id)
        put("ok", ok)
    }

    fun fileAttached(id: String, attachment: Attachment?, error: String? = null): JsonObject =
        buildJsonObject {
            put("type", "file.attached")
            put("id", id)
            if (attachment != null) {
                put("attachment", json.encodeToJsonElement(Attachment.serializer(), attachment))
            }
            if (error != null) {
                put("error", error)
            }
        }

    fun fileRemoved(id: String, ok: Boolean): JsonObject = buildJsonObject {
        put("type", "file.removed")
        put("id", id)
        put("ok", ok)
    }

    fun conversationExported(id: String, conversation: Conversation?): JsonObject = buildJsonObject {
        put("type", "conversation.export")
        put("id", id)
        put("json", conversation?.let {
            json.encodeToJsonElement(Conversation.serializer(), it).toString()
        } ?: "")
    }

    /** The reply to `backend.pair`; never carries a secret, key or token. */
    fun backendPair(ok: Boolean, error: String? = null): JsonObject = buildJsonObject {
        put("type", "backend.pair")
        put("ok", ok)
        if (!ok) put("error", error ?: "unknown")
    }

    fun deviceRequest(id: String, op: String, fields: JsonObjectBuilder.() -> Unit): JsonObject =
        buildJsonObject {
            put("type", "device.request")
            put("id", id)
            put("op", op)
            fields()
        }

    fun String.asObject(): JsonObject? = runCatching {
        json.parseToJsonElement(this).let { it as? JsonObject }
    }.getOrNull()

    fun JsonObject.type(): String? = this["type"]?.jsonPrimitive?.contentOrNull

    fun JsonObject.text(key: String): String = this[key]?.jsonPrimitive?.contentOrNull.orEmpty()

    fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.contentOrNull?.toIntOrNull()
}
