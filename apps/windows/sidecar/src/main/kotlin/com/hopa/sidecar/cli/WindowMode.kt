package com.hopa.sidecar.cli

import com.hopa.sidecar.approval.HostApproval
import com.hopa.sidecar.backend.BackendPairing
import com.hopa.sidecar.backend.BackendSession
import com.hopa.sidecar.backend.BackendSessionStore
import com.hopa.sidecar.backend.EngineTaskRunner
import com.hopa.sidecar.backend.GatewayHost
import com.hopa.sidecar.backend.backendContentKey
import com.hopa.sidecar.device.HostDevice
import com.hopa.sidecar.engine.Engine
import com.hopa.sidecar.protocol.Dispatcher
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.handlers.ApprovalHandler
import com.hopa.sidecar.protocol.handlers.BackendHandler
import com.hopa.sidecar.protocol.handlers.ConfigHandler
import com.hopa.sidecar.protocol.handlers.ConversationHandler
import com.hopa.sidecar.protocol.handlers.DeviceHandler
import com.hopa.sidecar.protocol.handlers.FileHandler
import com.hopa.sidecar.protocol.handlers.TaskHandler
import com.hopa.sidecar.protocol.handlers.TurnHandler
import com.hopa.sidecar.store.Attachments
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.PendingApprovals
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.store.TaskStore
import com.hopa.sidecar.support.Stdio
import com.hopa.sidecar.config.RuntimeConfig
import java.nio.file.Files
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking

/**
 * The window path: build the engine host's parts once, then hand every line to
 * the [Dispatcher]. Wiring lives here, message handling lives there.
 */
internal fun runProtocol(options: CliOptions) {
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
    val backendScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val sessionPath = dataDir.resolve("backend-session.json")
    val sessionStore = BackendSessionStore(sessionPath)
    val runner = EngineTaskRunner(
        startTurn = { id, goal -> engine.startTurn(id, goal, conversationId = null) },
        cancelTurn = engine::cancel,
    )
    engine.onTurnEnd = runner::complete
    val gateways = GatewayHost(
        io = io,
        store = store,
        records = records,
        sessionStore = sessionStore,
        runner = runner,
        scope = backendScope,
    )

    fun startStoredSession(): Boolean {
        val session = sessionStore.load()
        if (session == null) {
            if (Files.exists(sessionPath)) {
                io.log(
                    "backend admission: stored session is unreadable; " +
                        "encrypted tasks stay off until this PC pairs again",
                )
            } else {
                io.log("backend admission: none; encrypted tasks stay off until a phone pairs this PC")
            }
            return false
        }
        val contentKey = backendContentKey(session)
        if (contentKey == null) {
            io.log(
                "backend admission: found device ${session.deviceId}, but its content key is invalid; " +
                    "encrypted tasks stay off",
            )
            return false
        }
        io.log("backend admission: found device ${session.deviceId} in household ${session.householdId}")
        gateways.start(session, contentKey)
        return true
    }

    // `--pair-backend <url>` admits synchronously before the stdio loop, so a
    // host can launch the sidecar and watch stderr for the QR. A failure keeps
    // an existing stored session and lets the protocol command retry later.
    var started = false
    if (options.pairBackend != null) {
        try {
            runBlocking { BackendPairing(dataDir).admit(options.pairBackend, "Windows PC") }
            started = startStoredSession()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failed: Exception) {
            io.log("backend admission failed (${failed.javaClass.simpleName})")
        }
    }
    if (!started) startStoredSession()

    io.send(Protocol.ready())
    val denied = approvals.restoreAndDeny()
    if (denied > 0) {
        io.log("denied $denied pending approval(s) on restart")
    }
    io.log("ready (protocol v${Protocol.VERSION}), conversations at $dataDir, runs=${records.count()}")

    val dispatcher = Dispatcher(
        io = io,
        handlers = listOf(
            ConversationHandler(io, store),
            TurnHandler(io, engine),
            FileHandler(io, attachments),
            ConfigHandler(io, config),
            TaskHandler(io, tasks),
            DeviceHandler(io, device, config),
            ApprovalHandler(io, approval, config),
            BackendHandler(io, dataDir, sessionStore, gateways, backendScope),
        ),
    )
    while (true) {
        val line = readLine() ?: break
        if (!dispatcher.handle(line)) break
    }
}
