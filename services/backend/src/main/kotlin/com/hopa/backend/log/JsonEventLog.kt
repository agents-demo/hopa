package com.hopa.backend.log

import java.time.Instant
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * JSON on stdout. The forbidden set is dropped even if a caller passes it, so a
 * token or a message body cannot reach a log line by accident.
 */
class JsonEventLog(
    private val out: (String) -> Unit = { println(it) },
    private val clock: () -> Long = System::currentTimeMillis,
) : EventLog {
    override fun event(name: String, fields: Map<String, String>) {
        val line = buildJsonObject {
            put("event", name)
            put("at", Instant.ofEpochMilli(clock()).toString())
            fields.forEach { (key, value) ->
                if (key !in FORBIDDEN) put(key, value)
            }
        }.toString()
        out(line)
    }

    private companion object {
        val FORBIDDEN = setOf("token", "body", "authorization", "refresh", "access")
    }
}
