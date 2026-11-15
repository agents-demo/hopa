package com.hopa.backend.log

/**
 * Structured events. Implementations must never receive a token or a message
 * body: callers pass identifiers only, and [JsonEventLog] drops the forbidden
 * keys even if one slips through.
 */
fun interface EventLog {
    fun event(name: String, fields: Map<String, String>)

    companion object {
        val None = EventLog { _, _ -> }
    }
}
