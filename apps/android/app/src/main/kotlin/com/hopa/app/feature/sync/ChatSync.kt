package com.hopa.app.feature.sync

import com.hopa.capabilities.bridge.ChatTransport
import com.hopa.data.sessions.ConversationStore
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Push the whole local set, adopt the merged snapshot, and fall back to a plain
 * pull when the push does not reach the bridge.
 *
 * Tombstones travel both ways: a delete on another device is a server tombstone,
 * so the session is missing from the snapshot — a live local copy is then
 * deleted rather than resurrected. Empty drafts never leave the device.
 */
class ChatSync(
    private val conversations: ConversationStore,
    private val transport: ChatTransport,
) {
    suspend fun run(): ChatSyncReport {
        val local = conversations.allWithDeleted()
        val pushable = local.filter { it.messages.isNotEmpty() || it.title != "New chat" }
        var pulledFallback = false

        val snapshot = runCatching {
            transport.push(JsonArray(pushable.map(ChatSyncJson::encode)))
        }.getOrElse {
            pulledFallback = true
            transport.pull()
        }

        val remoteIds = mutableSetOf<String>()
        var adopted = 0
        for (item in snapshot["sessions"]?.jsonArray.orEmpty()) {
            val session = ChatSyncJson.decode(item.jsonObject)
            if (session.id.isBlank()) {
                continue
            }
            remoteIds += session.id
            conversations.adopt(session)
            adopted += 1
        }

        var tombstoned = 0
        if (!pulledFallback) {
            for (session in pushable) {
                if (session.deletedAt == 0L && session.id !in remoteIds) {
                    conversations.delete(session.id)
                    tombstoned += 1
                }
            }
        }

        return ChatSyncReport(
            rev = snapshot["rev"]?.jsonPrimitive?.intOrNull ?: 0,
            adopted = adopted,
            tombstoned = tombstoned,
            pulledFallback = pulledFallback,
        )
    }
}
