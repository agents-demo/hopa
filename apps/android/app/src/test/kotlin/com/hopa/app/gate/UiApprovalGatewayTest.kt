package com.hopa.app.gate

import com.hopa.core.contracts.Action
import com.hopa.core.gate.ApprovalRequest
import com.hopa.data.approvals.PendingApprovalStore
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UiApprovalGatewayTest {
    private val request = ApprovalRequest(
        title = "Confirm payment",
        body = "Money may leave your account.",
        amount = "25",
        merchant = "Coffee",
        consequence = "HOPA cannot undo a payment.",
        isPayment = true,
        action = Action(kind = "payment.checkout"),
    )

    @Test
    fun a_question_is_persisted_and_cleared_after_the_answer() = runBlocking {
        val store = FakeStore()
        val gateway = UiApprovalGateway(store, timeoutMillis = 5_000)
        var answer: Boolean? = null

        val job = launch { answer = gateway.approve(request) }
        yield()
        assertEquals(1, store.saved.size)

        gateway.resolve(true)
        job.join()

        assertEquals(true, answer)
        assertTrue(store.saved.isEmpty())
    }

    @Test
    fun an_unanswered_question_times_out_as_denied_and_is_cleared() = runBlocking {
        val store = FakeStore()
        val gateway = UiApprovalGateway(store, timeoutMillis = 100)

        assertFalse(gateway.approve(request))
        assertTrue(store.saved.isEmpty())
    }

    private class FakeStore : PendingApprovalStore {
        val saved = mutableListOf<ApprovalRequest>()

        override suspend fun save(request: ApprovalRequest) {
            saved += request
        }

        override suspend fun clear() {
            saved.clear()
        }

        override suspend fun clearAll() {
            saved.clear()
        }

        override suspend fun all(): List<ApprovalRequest> = saved.toList()
    }
}
