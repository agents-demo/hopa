package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.store.RecordStats
import com.hopa.sidecar.store.RecordStore
import kotlinx.serialization.json.JsonObject

/** The same usage counters Android computes from its run history. */
internal class UsageHandler(
    private val io: Stdio,
    private val records: RecordStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (type != "usage.summary") {
            return false
        }
        io.send(Protocol.usageSummary(message.text("id"), RecordStats.usage(records.all())))
        return true
    }
}
