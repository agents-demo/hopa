package com.hopa.backend.trace

import com.hopa.backend.protocol.Envelope
import com.hopa.backend.protocol.EnvelopeValidator
import java.util.UUID
import kotlinx.serialization.Serializable

/** Records one operation. Implementations must never fail the request. */
interface TraceRecorder {
    fun <T> span(
        householdId: String,
        traceId: String,
        operation: String,
        deviceId: String?,
        taskId: String?,
        block: () -> T,
    ): T

    companion object {
        val None = object : TraceRecorder {
            override fun <T> span(
                householdId: String,
                traceId: String,
                operation: String,
                deviceId: String?,
                taskId: String?,
                block: () -> T,
            ): T = block()
        }
    }
}

interface TraceQuery {
    fun spans(householdId: String, traceId: String): List<SpanView>
}

@Serializable
data class SpanView(
    val operation: String,
    val startedAt: String,
    val durationMs: Long,
    val status: String,
    val deviceId: String? = null,
    val taskId: String? = null,
)

object TraceIds {
    private val TRACEPARENT = Regex("^00-([0-9a-f]{32})-[0-9a-f]{16}-01$")
    private val TRACE_ID = Regex("^[0-9a-f]{32}$")

    fun traceId(traceparent: String?): String? =
        traceparent?.let { TRACEPARENT.matchEntire(it)?.groupValues?.get(1) }

    fun valid(traceId: String): Boolean = TRACE_ID.matches(traceId)

    fun newTraceparent(): String = EnvelopeValidator.traceOf(
        Envelope(
            v = 1,
            id = UUID.randomUUID().toString(),
            type = "ping",
            ts = 0,
        ),
    )
}
