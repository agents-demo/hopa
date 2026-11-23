package com.hopa.sidecar.protocol.handler

import com.hopa.contracts.wire.Approver
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.store.TaskStore
import com.hopa.sidecar.protocol.Stdio
import kotlinx.serialization.json.JsonObject

/**
 * Task shapes from `protocol.md`, as seen by the window: create, read, list,
 * hand off, and apply a gateway event. The phone transport lives elsewhere.
 */
internal class TaskHandler(
    private val io: Stdio,
    private val tasks: TaskStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        when (type) {
            "task.start" -> {
                val from = message.text("device").ifBlank { "pc" }
                val result = runCatching {
                    tasks.create(
                        id = message.text("taskId"),
                        goal = message.text("goal"),
                        from = from,
                    )
                }
                val task = result.getOrNull()
                if (task == null) {
                    io.send(
                        Protocol.taskError(
                            message.text("id"),
                            "task.start",
                            "E_SCHEMA",
                            result.exceptionOrNull()?.message ?: "bad task",
                        ),
                    )
                } else {
                    io.send(Protocol.task(message.text("id"), task))
                }
            }

            "task.get" -> {
                val task = tasks.get(message.text("taskId"))
                if (task == null) {
                    io.send(Protocol.taskError(message.text("id"), "task.get", "E_SCHEMA", "unknown task"))
                } else {
                    io.send(Protocol.task(message.text("id"), task, "task.get"))
                }
            }

            "task.list" -> io.send(Protocol.taskList(message.text("id"), tasks.list()))

            "task.handoff" -> {
                val target = message.text("target")
                val result = runCatching { tasks.handoff(message.text("taskId"), target) }
                val task = result.getOrNull()
                if (task == null) {
                    io.send(
                        Protocol.taskError(
                            message.text("id"),
                            "task.handoff",
                            "E_SCHEMA",
                            result.exceptionOrNull()?.message ?: "unknown task",
                        ),
                    )
                } else {
                    io.send(Protocol.task(message.text("id"), task, "task.handoff"))
                }
            }

            // The host forwards gateway task events; `from` is the server-set
            // device id, mapped to pc/phone. A `platform` on a result becomes
            // the approver label on the record (ADR-0024).
            "task.event" -> {
                val result = runCatching {
                    val platform = message.text("platform")
                    tasks.apply(
                        taskId = message.text("taskId"),
                        type = message.text("event"),
                        from = message.text("from").ifBlank { "pc" },
                        at = message.text("at").toLongOrNull() ?: System.currentTimeMillis(),
                        approver = platform.takeIf { it.isNotBlank() }?.let { Approver.fromPlatform(it) },
                        error = message.text("error").ifBlank { null },
                    )
                }
                val task = result.getOrNull()
                if (task == null) {
                    io.send(
                        Protocol.taskError(
                            message.text("id"),
                            "task.event",
                            "E_SCHEMA",
                            result.exceptionOrNull()?.message ?: "unknown task",
                        ),
                    )
                } else {
                    io.send(Protocol.task(message.text("id"), task, "task.event"))
                }
            }

            else -> return false
        }
        return true
    }
}
