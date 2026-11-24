package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.RecordStats
import com.hopa.sidecar.store.RecordStore
import kotlinx.serialization.json.JsonObject

/** The finished turns, flattened for the Windows history screen. */
internal class HistoryHandler(
    private val io: Stdio,
    private val records: RecordStore,
    private val store: ChatStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (type != "history.list") {
            return false
        }
        val id = message.text("id")
        val entries = RecordStats.history(records.all()) { conversationId ->
            store.get(conversationId)?.title ?: "New chat"
        }
        io.send(Protocol.historyList(id, entries))
        return true
    }
}
