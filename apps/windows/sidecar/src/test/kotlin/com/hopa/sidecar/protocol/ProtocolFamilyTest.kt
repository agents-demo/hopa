package com.hopa.sidecar.protocol

import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.wire.Action
import com.hopa.sidecar.capabilities.CapabilitiesSummary
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.store.HandoffTask
import kotlinx.serialization.json.JsonObject
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Every sidecar family has one stable envelope: a type, and an id when the
 * host is waiting for a reply. The payload-specific tests live next to each
 * family; this test is the map that catches a renamed or unaddressed family.
 */
class ProtocolFamilyTest {
    @Test
    fun every_family_has_a_stable_type_and_id() {
        val cases = linkedMapOf<String, JsonObject>(
            "ready" to Protocol.ready(),
            "log" to Protocol.log("hello"),
            "session" to Protocol.session("token", "refresh"),
            "backend.pair" to Protocol.backendPair(true),
            "configured" to Protocol.configured("c-1", false, "openai"),
            "turn.end" to Protocol.turnEnd(
                id = "t-1",
                conversationId = "c-1",
                title = "Title",
                answer = "Answer",
                steps = emptyList(),
                chainOk = true,
            ),
            "task.start" to Protocol.task("task-1", HandoffTask("h-1", "goal", "queued")),
            "task.list" to Protocol.taskList("task-1", emptyList()),
            "task.error" to Protocol.taskError("task-1", "task.start", "E_SCHEMA", "bad"),
            "approval.request" to Protocol.approvalRequest(
                "a-1",
                ApprovalRequest(
                    title = "Pay?",
                    body = "body",
                    amount = "10",
                    merchant = "shop",
                    consequence = "money",
                    isPayment = true,
                    action = Action(kind = "payment.pay"),
                ),
            ),
            "conversations.list" to Protocol.conversationList("c-1", emptyList()),
            "conversation.history" to Protocol.conversationOpened("c-1", null),
            "conversation.deleted" to Protocol.conversationDeleted("c-1", true),
            "conversation.export" to Protocol.conversationExported("c-1", null),
            "file.attached" to Protocol.fileAttached("f-1", null, "no file"),
            "file.removed" to Protocol.fileRemoved("f-1", true),
            "capabilities.summary" to Protocol.capabilities(
                "cap-1",
                CapabilitiesSummary(
                    platform = "windows",
                    profile = "everyday",
                    modelProvider = "openai",
                    modelName = "model",
                    modelReady = true,
                    bridge = false,
                    gatewayPaired = false,
                    phoneOnline = false,
                    memory = 0,
                    skills = 0,
                    recipes = 0,
                    runs = 0,
                    windowsApps = 0,
                ),
            ),
            "device.request" to Protocol.deviceRequest("d-1", "observe") {},
            "browser.request" to Protocol.browserRequest("b-1", "read") {},
        )

        val withoutId = setOf("ready", "log", "session", "backend.pair")
        for ((type, message) in cases) {
            assertEquals(type, message.text("type"), "$type envelope changed")
            if (type !in withoutId) {
                assertTrue(message.text("id").isNotBlank(), "$type lost its reply id")
            }
        }
    }
}
