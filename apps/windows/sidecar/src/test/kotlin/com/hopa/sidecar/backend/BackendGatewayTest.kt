package com.hopa.sidecar.backend

import com.hopa.backend.crypto.PayloadCipher
import com.hopa.backend.link.BackendLink
import com.hopa.backend.link.BackendState
import com.hopa.backend.wire.BackendEnvelope
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.charset.StandardCharsets
import java.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The gateway against a fake link (R30): the socket/reconnect behaviour is
 * already covered by `core/backend`, so this proves the frame handling, the
 * ciphertext both ways and the diagnostic exemption.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class BackendGatewayTest {
    private val contentKey = ByteArray(32) { (it + 1).toByte() }

    @Test
    fun `an encrypted create is acked once and answered with an encrypted result`() = runBlocking {
        val link = FakeLink()
        val sealed = seal("""{"goal":"open settings"}""")
        val gateway = BackendGateway(
            link = link,
            contentKey = contentKey,
            run = { goal -> "opened $goal" },
            clock = { 1_000 },
            newId = { "reply-1" },
        )
        gateway.attach()

        link.onTask!!.invoke(taskCreate(sealed))

        assertEquals(1, link.acked.size)
        assertEquals("task-1", link.acked.single().task)
        val reply = link.sent.single()
        assertEquals("task.result", reply.type)
        assertEquals("reply-1", reply.id)
        assertEquals(1_000, reply.ts)
        assertEquals("task-1", reply.task)
        assertEquals("phone-1", reply.to)
        assertEquals(TRACE, reply.trace)
        assertEquals("opened open settings", openText(reply))
    }

    @Test
    fun `a tampered ciphertext is an error and the next frame still runs`() = runBlocking {
        val link = FakeLink()
        val tampered = seal("""{"goal":"open settings"}""").also { sealed ->
            sealed[12] = (sealed[12].toInt() xor 0x01).toByte()
        }
        val gateway = BackendGateway(
            link = link,
            contentKey = contentKey,
            run = { "done" },
            clock = { 1_000 },
            newId = { "reply" },
        )
        gateway.attach()

        link.onTask!!.invoke(taskCreate(tampered, task = "task-1"))
        link.onTask!!.invoke(taskCreate(seal("""{"goal":"second"}"""), task = "task-2"))

        assertEquals(2, link.acked.size)
        assertEquals(2, link.sent.size)
        val error = link.sent[0]
        assertEquals("task.error", error.type)
        assertEquals("E_DECRYPT", error.body["code"]!!.jsonPrimitive.content)
        assertEquals("task-1", error.task)
        val recovered = link.sent[1]
        assertEquals("task.result", recovered.type)
        assertEquals("done", openText(recovered))
    }

    @Test
    fun `a body that is not a sealed envelope is a schema error and never runs`() = runBlocking {
        val link = FakeLink()
        var runs = 0
        val gateway = BackendGateway(link, contentKey, run = { runs++; "never" }, clock = { 1_000 }, newId = { "reply" })
        gateway.attach()

        link.onTask!!.invoke(
            BackendEnvelope(
                id = "m1",
                type = "task.create",
                ts = 1,
                from = "phone-1",
                to = "pc-1",
                task = "task-1",
                body = buildJsonObject { put("goal", "plaintext must not be accepted") },
            ),
        )

        val error = link.sent.single()
        assertEquals("task.error", error.type)
        assertEquals("E_SCHEMA", error.body["code"]!!.jsonPrimitive.content)
        assertEquals(0, runs)
    }

    @Test
    fun `a non-string sealed body is a schema error and never runs`() = runBlocking {
        val link = FakeLink()
        var runs = 0
        val gateway = BackendGateway(link, contentKey, run = { runs++; "never" }, clock = { 1_000 }, newId = { "reply" })
        gateway.attach()

        link.onTask!!.invoke(
            BackendEnvelope(
                id = "m1",
                type = "task.create",
                ts = 1,
                from = "phone-1",
                to = "pc-1",
                task = "task-1",
                body = buildJsonObject { put("sealed", 42) },
            ),
        )

        assertEquals("E_SCHEMA", link.sent.single().body["code"]!!.jsonPrimitive.content)
        assertEquals(0, runs)
    }

    @Test
    fun `diag ping echoes the body in plaintext with a pong`() = runBlocking {
        val link = FakeLink()
        val gateway = BackendGateway(link, contentKey, run = { "never" }, clock = { 4_242 }, newId = { "reply" })
        gateway.attach()

        link.onDiagnostic!!.invoke(diag("diag.ping", "diag-1", buildJsonObject { put("probe", "one") }))

        val reply = link.sent.single()
        assertEquals("task.result", reply.type)
        assertEquals("diag-1", reply.task)
        assertEquals("server", reply.to)
        assertTrue(reply.body["sealed"] == null)
        assertEquals("one", reply.body["probe"]!!.jsonPrimitive.content)
        assertEquals(4_242, reply.body["pong"]!!.jsonPrimitive.long)
        assertEquals(1, link.acked.size)
    }

    @Test
    fun `diag state reports the injected state and the windows platform`() = runBlocking {
        val link = FakeLink()
        val gateway = BackendGateway(
            link = link,
            contentKey = contentKey,
            run = { "never" },
            onDiagState = { buildJsonObject { put("conversations", 3) } },
            clock = { 1_000 },
            newId = { "reply" },
        )
        gateway.attach()

        link.onDiagnostic!!.invoke(diag("diag.state", "diag-2"))

        val body = link.sent.single().body
        assertEquals(3, body["conversations"]!!.jsonPrimitive.int)
        assertEquals("windows", body["platform"]!!.jsonPrimitive.content)
    }

    @Test
    fun `diag reset is accepted without a destructive action`() = runBlocking {
        val link = FakeLink()
        var runs = 0
        val gateway = BackendGateway(link, contentKey, run = { runs++; "never" }, clock = { 1_000 }, newId = { "reply" })
        gateway.attach()

        link.onDiagnostic!!.invoke(diag("diag.reset", "diag-3"))

        assertEquals("accepted", link.sent.single().body["reset"]!!.jsonPrimitive.content)
        assertEquals(0, runs)
    }

    @Test
    fun `non-task frames are ignored without a send`() = runBlocking {
        val link = FakeLink()
        val gateway = BackendGateway(link, contentKey, run = { "never" }, clock = { 1_000 }, newId = { "reply" })
        gateway.attach()

        val ignored = listOf("task.ack", "task.progress", "task.result", "task.error", "presence", "device.hello.ack", "error", "device.hello")
        ignored.forEachIndexed { index, type ->
            link.onTask!!.invoke(
                BackendEnvelope(
                    id = "m$index",
                    type = type,
                    ts = 1,
                    from = "peer",
                    to = "pc-1",
                    task = "task-$index",
                ),
            )
        }

        assertTrue(link.sent.isEmpty())
        assertTrue(link.acked.isEmpty())
    }

    @Test
    fun `a throwing run is a task error rather than a dead handler`() = runBlocking {
        val link = FakeLink()
        val gateway = BackendGateway(
            link = link,
            contentKey = contentKey,
            run = { throw IllegalStateException("model failed with secret-token") },
            clock = { 1_000 },
            newId = { "reply" },
        )
        gateway.attach()

        link.onTask!!.invoke(taskCreate(seal("""{"goal":"open settings"}""")))

        val error = link.sent.single()
        assertEquals("task.error", error.type)
        assertEquals("E_AGENT", error.body["code"]!!.jsonPrimitive.content)
        assertTrue(!error.body.toString().contains("secret-token"))
    }

    @Test
    fun `a failed reply send leaves the task unacked and the handler alive`() = runBlocking {
        val link = FakeLink().apply { sendFailures = 1 }
        val gateway = BackendGateway(link, contentKey, run = { "done" }, clock = { 1_000 }, newId = { "reply" })
        val stderr = ByteArrayOutputStream()
        val original = System.err
        System.setErr(PrintStream(stderr, true, StandardCharsets.UTF_8))
        try {
            gateway.attach()

            link.onTask!!.invoke(taskCreate(seal("""{"goal":"first"}"""), task = "task-1"))
            assertTrue(link.acked.isEmpty(), "a task whose reply never left must not be acked")
            assertTrue(link.sent.isEmpty())

            link.onTask!!.invoke(taskCreate(seal("""{"goal":"second"}"""), task = "task-2"))
            assertEquals(1, link.sent.size)
            assertEquals(1, link.acked.size)
            assertEquals("task-2", link.acked.single().task)
            assertTrue(stderr.toString(StandardCharsets.UTF_8).contains("send task.create task=task-1"))
        } finally {
            System.setErr(original)
        }
    }

    @Test
    fun `a failed ack still keeps the delivered reply and the handler alive`() = runBlocking {
        val link = FakeLink().apply { ackFailures = 1 }
        val gateway = BackendGateway(link, contentKey, run = { "done" }, clock = { 1_000 }, newId = { "reply" })
        val stderr = ByteArrayOutputStream()
        val original = System.err
        System.setErr(PrintStream(stderr, true, StandardCharsets.UTF_8))
        try {
            gateway.attach()

            link.onTask!!.invoke(taskCreate(seal("""{"goal":"first"}"""), task = "task-1"))
            link.onTask!!.invoke(taskCreate(seal("""{"goal":"second"}"""), task = "task-2"))

            assertEquals(2, link.sent.size)
            assertEquals(1, link.acked.size)
            assertEquals("task-2", link.acked.single().task)
            assertTrue(stderr.toString(StandardCharsets.UTF_8).contains("task.ack task.create task=task-1"))
        } finally {
            System.setErr(original)
        }
    }

    @Test
    fun `runForever attaches the handler and starts the link`() = runTest {
        val link = FakeLink()
        val gateway = BackendGateway(link, contentKey, run = { "never" })
        val scope = this

        val job = launch { gateway.runForever(scope) }
        runCurrent()

        assertEquals(1, link.starts)
        assertTrue(link.onTask != null)
        assertTrue(link.onDiagnostic != null)

        job.cancel()
        runCurrent()
    }

    private fun taskCreate(sealed: ByteArray, task: String = "task-1"): BackendEnvelope = BackendEnvelope(
        id = "m1",
        type = "task.create",
        ts = 1,
        trace = TRACE,
        from = "phone-1",
        to = "pc-1",
        task = task,
        body = buildJsonObject { put("sealed", base64Url(sealed)) },
    )

    private fun diag(type: String, task: String, body: JsonObject = JsonObject(emptyMap())): BackendEnvelope =
        BackendEnvelope(
            id = "m-$task",
            type = type,
            ts = 1,
            trace = TRACE,
            from = "server",
            to = "pc-1",
            task = task,
            body = body,
        )

    private fun seal(plaintext: String): ByteArray =
        PayloadCipher.seal(contentKey, plaintext.toByteArray(Charsets.UTF_8))

    private fun openText(reply: BackendEnvelope): String {
        val sealed = Base64.getUrlDecoder().decode(reply.body["sealed"]!!.jsonPrimitive.content)
        val plaintext = PayloadCipher.open(contentKey, sealed)
        return Json.parseToJsonElement(String(plaintext, Charsets.UTF_8))
            .jsonObject["text"]!!.jsonPrimitive.content
    }

    private fun base64Url(bytes: ByteArray): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

    private class FakeLink : BackendLink {
        private val _state = MutableStateFlow<BackendState>(BackendState.Disconnected)
        override val state: StateFlow<BackendState> = _state
        override var onTask: (suspend (BackendEnvelope) -> Unit)? = null
        override var onDiagnostic: (suspend (BackendEnvelope) -> Unit)? = null
        override var onApproval: (suspend (BackendEnvelope) -> Unit)? = null
        val sent = mutableListOf<BackendEnvelope>()
        val acked = mutableListOf<BackendEnvelope>()
        var starts = 0
        var sendFailures = 0
        var ackFailures = 0

        override fun start(scope: CoroutineScope) {
            starts++
        }

        override suspend fun stop() = Unit

        override suspend fun send(frame: BackendEnvelope) {
            if (sendFailures > 0) {
                sendFailures--
                throw IllegalStateException("the gateway link is not open")
            }
            sent += frame
        }

        override suspend fun ack(task: BackendEnvelope) {
            if (ackFailures > 0) {
                ackFailures--
                throw IllegalStateException("the gateway link is not open")
            }
            acked += task
        }

        override suspend fun ping() = Unit
    }

    private companion object {
        const val TRACE = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    }
}
