package com.hopa.sidecar

import com.hopa.contracts.chat.Attachment
import com.hopa.contracts.json.HopaJson
import com.hopa.contracts.wire.Approver
import com.hopa.sidecar.Protocol.asObject
import com.hopa.sidecar.Protocol.text
import com.hopa.sidecar.Protocol.type
import java.nio.file.Path
import kotlin.system.exitProcess
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject

private const val USAGE = """hopa-sidecar — the HOPA engine host for Windows

Usage:
  hopa-sidecar                        speak NDJSON on stdin/stdout (the window)
  hopa-sidecar --turn "say hello"     run one turn headless and print JSON
  hopa-sidecar --version

Options:
  --turn <goal>          run one turn, print the turn envelope on stdout, exit
  --data-dir <path>      conversations, records and attachments (default ~/.hopa/windows)
  --conversation <id>    continue that conversation instead of creating one
  --help                 print this text

Headless is deterministic by construction: no model key is loaded, so the engine
uses the scripted proposer, and no host is attached, so approvals deny and
actions refuse. Nothing in headless mode can allow an action."""

fun main(args: Array<String>) {
    val options = runCatching { CliOptions.parse(args) }.getOrElse { error ->
        System.err.println("hopa-sidecar: ${error.message}")
        System.err.println(USAGE)
        exitProcess(2)
    }
    if (options.help) {
        println(USAGE)
        return
    }
    if (options.version) {
        println("hopa-sidecar protocol v${Protocol.VERSION}")
        return
    }
    if (options.turn != null) {
        exitProcess(runHeadless(options))
    }
    runProtocol(options)
}

/** One turn through the real loop, the real gate and the fail-closed stubs. */
private fun runHeadless(options: CliOptions): Int {
    val io = Stdio()
    val dataDir = options.dataDir ?: defaultDataDir()
    val store = ChatStore(dataDir.resolve("conversations.json"))
    val records = RecordStore(dataDir.resolve("records.json"))
    val approvals = DenyAllApproval()
    val engine = Engine(
        io = io,
        hostDevice = HeadlessDevice(),
        approval = approvals,
        store = store,
        recordStore = records,
        config = RuntimeConfig(),
        forceStub = true,
        deviceAttached = false,
    )
    val outcome = runBlocking {
        engine.runTurn(
            id = "cli-1",
            goal = options.turn.orEmpty(),
            conversationId = options.conversationId,
        )
    }
    println(Protocol.headlessTurn("cli-1", outcome).toString())
    io.log(
        "headless turn done: records=${outcome.records.size} " +
            "approvals=${approvals.requests} chainOk=${outcome.chainOk}",
    )
    return 0
}

/** The window path: one message per line in, one message per line out. */
private fun runProtocol(options: CliOptions) {
    val io = Stdio()
    val device = HostDevice(io)
    val dataDir = options.dataDir ?: defaultDataDir()
    val store = ChatStore(dataDir.resolve("conversations.json"))
    val approvals = PendingApprovals(dataDir.resolve("approvals.json"))
    val records = RecordStore(dataDir.resolve("records.json"))
    val config = RuntimeConfig()
    val approval = HostApproval(io, approvals)
    val attachments = Attachments(dataDir.resolve("attachments"))
    val tasks = TaskStore()
    val engine = Engine(io, device, approval, store, records, config)
    io.send(Protocol.ready())
    val denied = approvals.restoreAndDeny()
    if (denied > 0) {
        io.log("denied $denied pending approval(s) on restart")
    }
    io.log("ready (protocol v${Protocol.VERSION}), conversations at $dataDir, runs=${records.count()}")
    while (true) {
        val line = readLine() ?: break
        if (line.isBlank()) continue
        val message = line.asObject() ?: continue
        when (message.type()) {
            "hello" -> io.send(Protocol.ready())
            "conversations.list" ->
                io.send(
                    Protocol.conversationList(
                        message.text("id"),
                        store.list(message.text("includeArchived").toBoolean()),
                    ),
                )

            "conversation.pin" ->
                io.send(
                    Protocol.conversationOpened(
                        message.text("id"),
                        store.setPinned(message.text("conversationId"), message.text("pinned").toBoolean()),
                    ),
                )

            "conversation.archive" ->
                io.send(
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

            "conversation.rename" ->
                io.send(
                    Protocol.conversationOpened(
                        message.text("id"),
                        store.rename(message.text("conversationId"), message.text("title")),
                    ),
                )

            "conversation.delete" ->
                io.send(
                    Protocol.conversationDeleted(
                        message.text("id"),
                        store.delete(message.text("conversationId")),
                    ),
                )

            "conversation.export" ->
                io.send(
                    Protocol.conversationExported(
                        message.text("id"),
                        store.get(message.text("conversationId")),
                    ),
                )

            "configure" -> {
                config.update(message)
                io.log("configured: ${config.summary()}")
                io.send(Protocol.configured(message.text("id"), config.useBridge, config.modelProvider))
            }

            "turn.start" -> {
                val attachment = (message["attachment"] as? JsonObject)?.let {
                    HopaJson.element.decodeFromJsonElement(Attachment.serializer(), it)
                }
                engine.startTurn(
                    id = message.text("id"),
                    goal = message.text("goal"),
                    conversationId = message.text("conversationId").ifBlank { null },
                    attachment = attachment,
                )
            }

            "file.attach" -> {
                val path = message.text("path")
                val result = runCatching { attachments.accept(Path.of(path)) }
                io.send(
                    Protocol.fileAttached(
                        id = message.text("id"),
                        attachment = result.getOrNull(),
                        error = result.exceptionOrNull()?.message,
                    ),
                )
            }

            "file.remove" -> {
                attachments.remove(message.text("path"))
                io.send(Protocol.fileRemoved(message.text("id"), true))
            }

            "turn.cancel" -> engine.cancel()

            // P4: the task shapes are implemented against protocol.md. The
            // transport that carries them to the phone is added with the phone
            // receiver; until then a task can be created and handed to "pc"
            // locally, and a handoff to "phone" fails honestly.
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
                    io.send(Protocol.taskError(
                        message.text("id"), "task.start", "E_SCHEMA",
                        result.exceptionOrNull()?.message ?: "bad task",
                    ))
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
                    io.send(Protocol.taskError(
                        message.text("id"), "task.handoff", "E_SCHEMA",
                        result.exceptionOrNull()?.message ?: "unknown task",
                    ))
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
                    io.send(Protocol.taskError(
                        message.text("id"), "task.event", "E_SCHEMA",
                        result.exceptionOrNull()?.message ?: "unknown task",
                    ))
                } else {
                    io.send(Protocol.task(message.text("id"), task, "task.event"))
                }
            }

            "device.result" -> device.resolve(message.text("id"), message)
            // The .NET host owns the gateway socket. It tells the sidecar only
            // whether a phone peer is reachable, so a phone answer can be
            // attributed honestly and a forged one is refused.
            "gateway.state" -> config.setGatewayState(
                paired = message.text("paired").toBoolean(),
                phoneOnline = message.text("phoneOnline").toBoolean(),
            )
            "approval.result" -> {
                val id = message.text("id")
                val claimed = message.text("device").ifBlank { "pc" }
                val allow = message.text("allow").toBoolean()
                // ADR-0024: a phone answer cannot be trusted when no phone link
                // exists — there is no path for the phone to have answered.
                // Refuse it rather than believe the claim (fail closed).
                if (claimed == "phone" && !config.hasPhoneLink) {
                    io.log("refused an approval claiming the phone: no phone link is attached")
                    approval.resolve(id, false, "pc")
                } else {
                    approval.resolve(id, allow, claimed)
                }
            }
            "shutdown" -> return
            else -> io.log("unknown message: ${message.type()}")
        }
    }
}

private fun defaultDataDir(): Path =
    System.getenv("HOPA_DATA_DIR")
        ?.takeIf { it.isNotBlank() }
        ?.let { Path.of(it) }
        ?: Path.of(System.getProperty("user.home"), ".hopa", "windows")

/** The `--turn` CLI. Unknown options fail closed instead of being ignored. */
internal data class CliOptions(
    val turn: String? = null,
    val dataDir: Path? = null,
    val conversationId: String? = null,
    val help: Boolean = false,
    val version: Boolean = false,
) {
    companion object {
        fun parse(args: Array<String>): CliOptions {
            var turn: String? = null
            var dataDir: Path? = null
            var conversationId: String? = null
            var help = false
            var version = false
            var index = 0
            while (index < args.size) {
                val arg = args[index]
                when {
                    arg == "--turn" -> {
                        turn = args.getOrNull(++index)
                            ?: throw IllegalArgumentException("--turn needs a goal")
                    }

                    arg.startsWith("--turn=") -> turn = arg.removePrefix("--turn=")

                    arg == "--data-dir" -> {
                        dataDir = Path.of(
                            args.getOrNull(++index)
                                ?: throw IllegalArgumentException("--data-dir needs a path"),
                        )
                    }

                    arg.startsWith("--data-dir=") -> dataDir = Path.of(arg.removePrefix("--data-dir="))

                    arg == "--conversation" -> {
                        conversationId = args.getOrNull(++index)
                            ?: throw IllegalArgumentException("--conversation needs an id")
                    }

                    arg.startsWith("--conversation=") ->
                        conversationId = arg.removePrefix("--conversation=")

                    arg == "--help" || arg == "-h" -> help = true

                    arg == "--version" -> version = true

                    else -> throw IllegalArgumentException("unknown option: $arg")
                }
                index += 1
            }
            return CliOptions(
                turn = turn,
                dataDir = dataDir,
                conversationId = conversationId,
                help = help,
                version = version,
            )
        }
    }
}
