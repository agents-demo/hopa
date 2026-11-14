package com.hopa.core.parser

import com.hopa.core.contracts.Action
import com.hopa.core.contracts.ActionKind
import com.hopa.core.contracts.Decision
import com.hopa.core.contracts.ErrorCodes
import com.hopa.core.contracts.HopaError
import com.hopa.core.json.HopaJson
import com.hopa.core.validation.DecisionRules
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class DecisionParser {
    fun parse(raw: String): ParseOutcome {
        val text = raw.trim()
        if (text.isEmpty()) {
            return ParseOutcome(text = raw)
        }
        direct(text)?.let { return it }
        val objects = BalancedObjectScanner.scan(text)
        for (candidate in objects.asReversed()) {
            direct(candidate)?.let { return it }
        }
        return ParseOutcome(text = raw)
    }

    private fun direct(value: String): ParseOutcome? {
        val payload = stripFence(value)
        if (!payload.startsWith("{")) {
            return null
        }
        val element = runCatching { HopaJson.element.parseToJsonElement(payload) }.getOrNull()
            ?: return null
        val obj = element as? JsonObject ?: return null
        return decode(obj)
    }

    private fun decode(raw: JsonObject): ParseOutcome {
        val obj = if (raw.containsKey("isPayment")) JsonObject(raw.filterKeys { key -> key != "isPayment" }) else raw
        val kind = obj["kind"]?.asString()
        if (kind == "finish" || kind == "done") {
            return ParseOutcome(text = obj.toString())
        }
        if (kind != null) {
            if (ActionKind.fromWire(kind) == null) {
                return ParseOutcome(
                    error = HopaError(ErrorCodes.SCHEMA, "unknown action kind: $kind"),
                )
            }
            return actionDecision(obj, kind)
        }
        val decision = runCatching {
            HopaJson.element.decodeFromJsonElement(Decision.serializer(), obj)
        }.getOrElse {
            return ParseOutcome(
                error = HopaError(ErrorCodes.SCHEMA, "invalid decision: ${it.message}"),
            )
        }
        val validation = DecisionRules.validate(decision)
        if (!validation.valid) {
            return ParseOutcome(
                error = HopaError(
                    validation.errorCode ?: ErrorCodes.SCHEMA,
                    validation.message ?: "invalid decision",
                ),
            )
        }
        return ParseOutcome(decision = decision)
    }

    private fun actionDecision(obj: JsonObject, kind: String): ParseOutcome {
        val action = Action(
            schemaVersion = obj["schemaVersion"]?.asString() ?: "1",
            kind = kind,
            ref = obj["ref"]?.asString() ?: obj["target"]?.asString(),
            text = obj["text"]?.asString(),
            x = obj["x"]?.asInt(),
            y = obj["y"]?.asInt(),
            toX = obj["toX"]?.asInt(),
            toY = obj["toY"]?.asInt(),
            app = obj["app"]?.asString(),
            url = obj["url"]?.asString(),
            direction = obj["direction"]?.asString(),
            timeoutMs = obj["timeoutMs"]?.asInt() ?: 3000,
        )
        return ParseOutcome(
            decision = Decision(
                action = action,
                say = obj["say"]?.asString() ?: "",
                done = false,
                needUser = false,
            ),
        )
    }

    private fun stripFence(value: String): String {
        var text = value.trim()
        if (text.startsWith("```")) {
            text = text.replaceFirst(Regex("^```[a-zA-Z]*\\s*"), "")
            text = text.replace(Regex("```\\s*$"), "")
        }
        return text.trim()
    }

    private fun JsonElement.asString(): String? = runCatching {
        jsonPrimitive.contentOrNull
    }.getOrNull()

    private fun JsonElement.asInt(): Int? = runCatching {
        jsonPrimitive.intOrNull
    }.getOrNull()
}
