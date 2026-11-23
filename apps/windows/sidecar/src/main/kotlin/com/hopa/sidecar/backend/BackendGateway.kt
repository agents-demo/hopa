package com.hopa.sidecar.backend

import com.hopa.backend.crypto.PayloadCipher
import com.hopa.backend.link.BackendLink
import com.hopa.backend.wire.BackendEnvelope
import java.util.Base64
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.awaitCancellation
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put

/**
 * The sidecar's side of the gateway: encrypted `task.create` in, the engine's
 * answer sealed into `task.result`, and the plaintext `diag.*` exemption.
 *
 * Bodies are the R29 convention: a real task body is
 * `{"sealed": base64url(IV(12) || ciphertext || tag(16))}` under the household
 * content key, with plaintext `{"goal": ...}` inbound and `{"text": ...}`
 * outbound. Diagnostics (and only diagnostics) travel in plaintext.
 *
 * A malformed or unauthenticated body becomes a `task.error`, never a thrown
 * handler: one bad frame must not cost the link. Log lines carry the frame
 * type and task id only, never a body, a key or a token.
 */
class BackendGateway(
    private val link: BackendLink,
    private val contentKey: ByteArray,
    private val run: suspend (goal: String) -> String,
    private val onDiagState: () -> JsonObject = { JsonObject(emptyMap()) },
    private val clock: () -> Long = System::currentTimeMillis,
    private val newId: () -> String = { UUID.randomUUID().toString() },
) {
    init {
        require(contentKey.size == CONTENT_KEY_BYTES) {
            "content key must be $CONTENT_KEY_BYTES bytes"
        }
    }

    /** Points the link's delivery seams at this gateway. */
    fun attach() {
        link.onTask = { frame -> dispatch(frame) }
        // `diag.*` is plaintext and goal-less; the shared client keeps it off
        // the goal-bearing task handler so Android never turns it into a task.
        link.onDiagnostic = { frame -> dispatch(frame) }
    }

    /**
     * Handles one delivered frame and returns the reply to send, or null when
     * the frame is not ours. Visible for tests; [attach] wires it to the link.
     */
    suspend fun handle(frame: BackendEnvelope): BackendEnvelope? = when {
        frame.type == "task.create" -> handleCreate(frame)
        frame.type in DIAG_TYPES -> handleDiag(frame)
        else -> null
    }

    /**
     * Starts the link and keeps this coroutine alive until the caller's scope
     * is cancelled. Handler failures are caught per frame, so a thrown turn
     * never kills the link.
     */
    suspend fun runForever(scope: CoroutineScope) {
        attach()
        link.start(scope)
        awaitCancellation()
    }

    private suspend fun handleCreate(frame: BackendEnvelope): BackendEnvelope {
        val sealedText = (frame.body["sealed"] as? JsonPrimitive)
            ?.takeIf { it.isString }
            ?.contentOrNull
            ?.takeIf { it.isNotBlank() }
            ?: return error(frame, "E_SCHEMA", "task.create needs a sealed body")

        val blob = try {
            Base64.getUrlDecoder().decode(sealedText)
        } catch (malformed: IllegalArgumentException) {
            return error(frame, "E_DECRYPT", "the sealed task body is not base64url")
        }
        val plaintext = try {
            PayloadCipher.open(contentKey, blob)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (unauthentic: Exception) {
            // Tampered ciphertext, a wrong key or a truncated blob.
            return error(frame, "E_DECRYPT", "the sealed task body failed authentication")
        }
        val goal = try {
            val body = Json.parseToJsonElement(String(plaintext, Charsets.UTF_8)).jsonObject
            (body["goal"] as? JsonPrimitive)
                ?.takeIf { it.isString }
                ?.contentOrNull
                ?.takeIf { it.isNotBlank() }
        } catch (malformed: Exception) {
            null
        } ?: return error(frame, "E_SCHEMA", "the sealed task body is not a goal")

        val answer = try {
            run(goal)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failed: Exception) {
            // The exception text may quote the goal or a model reply, so only
            // the class name is logged and only a stable code is sent.
            warn("task.create task=${frame.task} run failed (${failed.javaClass.simpleName})")
            return error(frame, "E_AGENT", "the sidecar could not run the task")
        }

        val sealed = PayloadCipher.seal(
            contentKey,
            buildJsonObject { put("text", answer) }.toString().toByteArray(Charsets.UTF_8),
        )
        return result(frame, buildJsonObject { put("sealed", base64Url(sealed)) })
    }

    private suspend fun handleDiag(frame: BackendEnvelope): BackendEnvelope {
        val body = when (frame.type) {
            "diag.ping" -> JsonObject(frame.body + ("pong" to JsonPrimitive(clock())))
            "diag.state" -> {
                val state = runCatching { onDiagState() }.getOrElse { JsonObject(emptyMap()) }
                JsonObject(state + ("platform" to JsonPrimitive("windows")))
            }
            else -> buildJsonObject { put("reset", "accepted") }
        }
        return result(frame, body)
    }

    /**
     * Sends the reply first and acks only then. A failed send leaves the task
     * unacked, so the server redelivers it after a reconnect.
     */
    private suspend fun acknowledge(frame: BackendEnvelope) {
        try {
            link.ack(frame)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failed: Exception) {
            warn("task.ack ${frame.type} task=${frame.task} failed (${failed.javaClass.simpleName})")
        }
    }

    private suspend fun dispatch(frame: BackendEnvelope) {
        try {
            val reply = handle(frame) ?: return
            try {
                link.send(reply)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failed: Exception) {
                warn("send ${frame.type} task=${frame.task} failed (${failed.javaClass.simpleName})")
                return
            }
            acknowledge(frame)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failed: Exception) {
            warn("${frame.type} task=${frame.task} failed (${failed.javaClass.simpleName})")
        }
    }

    private fun result(frame: BackendEnvelope, body: JsonObject): BackendEnvelope = BackendEnvelope(
        id = newId(),
        type = "task.result",
        ts = clock(),
        trace = frame.trace,
        to = frame.from,
        task = frame.task,
        body = body,
    )

    private fun error(frame: BackendEnvelope, code: String, message: String): BackendEnvelope = BackendEnvelope(
        id = newId(),
        type = "task.error",
        ts = clock(),
        trace = frame.trace,
        to = frame.from,
        task = frame.task,
        body = buildJsonObject {
            put("code", code)
            put("message", message)
            put("retryable", false)
        },
    )

    private fun base64Url(bytes: ByteArray): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

    /** Identifier-only; a body or an exception text could carry a secret. */
    private fun warn(text: String) {
        System.err.println("[gateway] $text")
        System.err.flush()
    }

    private companion object {
        const val CONTENT_KEY_BYTES = 32
        val DIAG_TYPES = setOf("diag.ping", "diag.state", "diag.reset")
    }
}
