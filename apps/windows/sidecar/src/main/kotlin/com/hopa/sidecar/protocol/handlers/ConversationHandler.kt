package com.hopa.sidecar.protocol.handlers

import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.support.Stdio
import kotlinx.serialization.json.JsonObject

/** Listing, naming and archiving conversations; one message in, one reply out. */
internal class ConversationHandler(
    private val io: Stdio,
    private val store: ChatStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        when (type) {
            "conversations.list" -> io.send(
                Protocol.conversationList(
                    message.text("id"),
                    store.list(message.text("includeArchived").toBoolean()),
                ),
            )

            "conversation.pin" -> io.send(
                Protocol.conversationOpened(
                    message.text("id"),
                    store.setPinned(message.text("conversationId"), message.text("pinned").toBoolean()),
                ),
            )

            "conversation.archive" -> io.send(
                Protocol.conversationOpened(
                    message.text("id"),
                    store.setArchived(message.text("conversationId"), message.text("archived").toBoolean()),
                ),
            )

            "conversation.create" ->
                io.send(Protocol.conversationOpened(message.text("id"), store.create()))

            "conversation.open" ->
                io.send(Protocol.conversationOpened(message.text("id"), store.get(message.text("conversationId"))))

            "conversation.search" ->
                io.send(Protocol.conversationList(message.text("id"), store.search(message.text("query"))))

            "conversation.rename" -> io.send(
                Protocol.conversationOpened(
                    message.text("id"),
                    store.rename(message.text("conversationId"), message.text("title")),
                ),
            )

            "conversation.delete" -> io.send(
                Protocol.conversationDeleted(
                    message.text("id"),
                    store.delete(message.text("conversationId")),
                ),
            )

            "conversation.export" -> io.send(
                Protocol.conversationExported(
                    message.text("id"),
                    store.get(message.text("conversationId")),
                ),
            )

            else -> return false
        }
        return true
    }
}
