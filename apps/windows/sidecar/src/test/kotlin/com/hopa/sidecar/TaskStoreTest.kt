package com.hopa.sidecar

import com.hopa.contracts.wire.Approver
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** P4: the local task view mirrors the backend gateway state machine (ADR-0024). */
class TaskStoreTest {
    private val store = TaskStore()

    @Test
    fun a_created_task_is_queued_with_a_create_event() {
        val task = store.create("t-1", "open notepad")

        assertEquals("t-1", task.id)
        assertEquals("queued", task.state)
        assertEquals("pc", task.from)
        assertEquals(1, task.events.size)
        assertEquals("task.create", task.events[0].type)
        assertNull(task.to)
        assertNull(task.approver)
    }

    @Test
    fun a_blank_id_gets_a_generated_one() {
        assertTrue(store.create("", "open notepad").id.startsWith("t-"))
    }

    @Test
    fun a_handoff_records_the_gateway_target_but_not_a_delivery() {
        store.create("t-1", "open notepad")
        val moved = store.handoff("t-1", "phone")

        assertEquals("phone", moved!!.to)
        assertEquals("queued", moved.state)
        assertEquals(1, moved.events.size)
    }

    @Test
    fun gateway_events_move_the_state_exactly_as_the_router_does() {
        store.create("t-1", "open notepad")
        store.handoff("t-1", "phone")

        assertEquals("delivered", store.apply("t-1", "deliver", "phone")!!.state)
        assertEquals("acked", store.apply("t-1", "task.ack", "phone")!!.state)
        assertEquals("progress", store.apply("t-1", "task.progress", "phone")!!.state)
        assertEquals("done", store.apply("t-1", "task.result", "phone")!!.state)
    }

    @Test
    fun an_approval_request_is_its_own_state_then_a_result_finishes_it() {
        store.create("t-1", "approve a payment")
        store.handoff("t-1", "phone")

        assertEquals("needs_approval", store.apply("t-1", "task.needs_approval", "pc")!!.state)
        val done = store.apply("t-1", "task.result", "phone")
        assertEquals("done", done!!.state)
        assertEquals("phone", done.events.last().from)
    }

    @Test
    fun a_result_from_the_phone_sets_the_approver() {
        store.create("t-1", "pay 100")
        val approver = Approver("phone", 1234)
        val done = store.apply("t-1", "task.result", "phone", approver = approver)

        assertEquals("done", done!!.state)
        assertEquals(approver, done.approver)
        assertEquals("phone", done.events.last().from)
    }

    @Test
    fun an_error_is_a_failed_task_with_a_readable_message() {
        store.create("t-1", "open notepad")
        val failed = store.apply("t-1", "task.error", "phone", error = "device refused")

        assertEquals("failed", failed!!.state)
        assertTrue(failed.error!!.contains("device refused"))
    }

    @Test
    fun a_dropped_link_is_a_task_error_and_the_task_stays_readable() {
        store.create("t-1", "open notepad")
        store.handoff("t-1", "phone")
        val failed = store.failLink("t-1", "gateway closed")

        assertEquals("failed", failed!!.state)
        assertTrue(failed.error!!.contains("dropped"))
        assertEquals("task.error", failed.events.last().type)
    }

    @Test
    fun cancel_is_a_terminal_state() {
        store.create("t-1", "open notepad")
        assertEquals("cancelled", store.apply("t-1", "task.cancel", "pc")!!.state)
    }

    @Test
    fun an_unknown_task_or_event_is_not_silently_accepted() {
        assertNull(store.get("missing"))
        assertNull(store.handoff("missing", "phone"))
        assertNull(store.apply("missing", "task.ack"))
        val created = store.create("t-1", "goal")
        assertEquals(1, created.events.size)
    }

    @Test
    fun an_event_from_an_unknown_device_is_refused() {
        store.create("t-1", "goal")
        val error = runCatching { store.apply("t-1", "task.ack", "tablet") }.exceptionOrNull()
        assertNotNull(error)
    }

    @Test
    fun the_gateway_task_shape_is_echoed_on_the_wire() {
        store.create("t-1", "open notepad")
        store.handoff("t-1", "phone")
        store.apply("t-1", "deliver", "phone")
        val task = store.apply("t-1", "task.result", "phone", approver = Approver("phone", 1234))!!
        val envelope = Protocol.task("reply", task)

        assertEquals("task.start", envelope["type"]?.toString()?.trim('"'))
        val body = envelope["task"].toString()
        assertTrue(body.contains("\"state\":\"done\""))
        assertTrue(body.contains("\"events\""))
        assertTrue(body.contains("\"type\":\"task.result\""))
        assertTrue(body.contains("\"approver\""))
    }

    @Test
    fun gateway_platform_maps_to_the_record_device() {
        assertEquals("pc", Approver.fromPlatform("windows").device)
        assertEquals("phone", Approver.fromPlatform("android").device)
    }
}
