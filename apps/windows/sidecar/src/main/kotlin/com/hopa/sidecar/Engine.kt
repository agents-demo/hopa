package com.hopa.sidecar

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.action.ApprovalPolicy
import com.hopa.agent.decision.model.ModelDecisionPolicy
import com.hopa.agent.decision.model.ModelStepPolicy
import com.hopa.agent.loop.AgentLoop
import com.hopa.bridge.device.AdbDevice
import com.hopa.bridge.session.BridgeClient
import com.hopa.catalog.routing.CatalogRoutes
import com.hopa.contracts.approval.ApprovalGateway
import com.hopa.contracts.chat.Attachment
import com.hopa.contracts.model.ModelMessage
import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.ports.DevicePort
import com.hopa.contracts.ports.InstalledApp
import com.hopa.contracts.turn.TurnContext
import com.hopa.contracts.wire.RunRecord
import com.hopa.inference.client.ModelFactory
import com.hopa.runlog.record.RunChain
import com.hopa.runlog.record.RunRecordDraft
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.runlog.store.InMemoryRunRecorder
import com.hopa.runlog.store.RunRecorder
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** What one turn produced, for the protocol and for `--turn`. */
data class TurnOutcome(
    val conversationId: String,
    val title: String,
    val answer: String,
    val records: List<RunRecord>,
    val chainOk: Boolean,
    val narration: List<String> = emptyList(),
    val error: String? = null,
)

/**
 * One turn at a time; the loop and the gate are the real ones.
 *
 * P1 adds `runTurn`, a suspend function that returns the outcome instead of
 * writing to stdout. The window path (`startTurn`) and the headless path
 * (`--turn`) share it, so there is exactly one execution path.
 */
class Engine(
    private val io: Stdio,
    private val hostDevice: DevicePort,
    private val approval: ApprovalGateway,
    private val store: ChatStore,
    private val recordStore: RecordStore,
    private val config: RuntimeConfig,
    private val forceStub: Boolean = false,
    /** False in headless: no host is attached, so the prompt must not claim access. */
    private val deviceAttached: Boolean = true,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val clock = SystemClock()
    private val turnLock = Mutex()

    @Volatile
    private var cancelled = false

    fun cancel() {
        cancelled = true
        io.log("turn cancelled by the user")
    }

    /**
     * The apps this PC can open, from the catalog's windows column. There is no
     * installed-app inventory here yet, so only entries we know how to start are
     * offered, and the prompt says a launch may still fail.
     */
    private fun windowsApps(): List<InstalledApp> = CatalogRoutes
        .targets(platform = "windows", knowledge = SidecarKnowledge.value)
        .filter { it.kind == "app" && it.bundle.isNotEmpty() }
        .map { InstalledApp(packageName = it.bundle, label = it.display) }

    /** The window path: launch the turn, stream `step` events, finish with `turn.end`. */
    fun startTurn(
        id: String,
        goal: String,
        conversationId: String?,
        attachment: Attachment? = null,
    ) {
        scope.launch {
            var lastAt = System.currentTimeMillis()
            val outcome = runTurn(id, goal, conversationId, attachment) { index, record ->
                val now = System.currentTimeMillis()
                io.send(Protocol.step(id, index, record, now, now - lastAt))
                lastAt = now
            }
            io.send(
                Protocol.turnEnd(
                    id = id,
                    conversationId = outcome.conversationId,
                    title = outcome.title,
                    answer = outcome.answer,
                    steps = outcome.records,
                    chainOk = outcome.chainOk,
                ),
            )
        }
    }

    /**
     * The one execution path. Serialised: a second turn waits for the first, so
     * two windows cannot interleave device actions or records.
     */
    suspend fun runTurn(
        id: String,
        goal: String,
        conversationId: String?,
        attachment: Attachment? = null,
        onRecord: ((Int, RunRecord) -> Unit)? = null,
    ): TurnOutcome = turnLock.withLock {
        cancelled = false
        val requested = conversationId?.takeIf { it.isNotBlank() }
        val existing = requested?.let { store.get(it) }
        if (requested != null && existing == null) {
            io.log("unknown conversation $requested; starting a new one")
        }
        val conversation = existing ?: store.create()
        val history = conversation.messages.map { ModelMessage(it.role, it.text) }
        store.append(conversation.id, "user", goal, attachment)
        io.log("turn $id in ${conversation.id}: $goal")

        val device = device()
        val model = model()
        // Windows picks a path per action; the phone target keeps its own order
        // until P4 gives it a selector.
        val selector = if (config.hasBridge) null else WindowsPathSelector()
        val system = if (config.hasBridge) {
            null
        } else {
            (hostDevice as? HostDevice)?.let { HostSystem(it) }
        }
        val memory = InMemoryRunRecorder()
        val recorder = if (onRecord == null) memory else EmittingRecorder(memory, onRecord)

        val executor = ActionExecutor(
            device = device,
            browser = null,
            system = system,
            sandbox = null,
            policy = { ApprovalPolicy() },
            approval = approval,
            recorder = recorder,
            factory = RunRecordFactory(clock),
            clock = clock,
            selector = selector,
            onFallback = { message -> io.log(message) },
        )
        val loop = AgentLoop(
            policy = ModelDecisionPolicy(
                steps = ModelStepPolicy(model),
                knowledge = { SidecarKnowledge.value },
            ),
            device = device,
            executor = executor,
            recorder = recorder,
            clock = clock,
            webAvailable = false,
            knowledge = SidecarKnowledge.value,
        )
        val outcome = runCatching {
            loop.run(
                runId = "run-$id",
                traceId = UUID.randomUUID().toString(),
                context = TurnContext(
                    goal = goal,
                    history = history,
                    platform = "windows",
                    installedApps = windowsApps(),
                    phoneAccess = deviceAttached,
                ),
                isCancelled = { cancelled },
            )
        }

        val result = outcome.getOrNull()
        val answer = result?.answer
            ?: "The sidecar failed: ${outcome.exceptionOrNull()?.message ?: "unknown error"}"
        val records = result?.records.orEmpty()
        recordStore.append(conversation.id, "run-$id", records)
        val chainOk = records.isEmpty() || RunChain.verify(records)
        store.append(conversation.id, "assistant", answer)
        val updated = store.get(conversation.id)
        TurnOutcome(
            conversationId = conversation.id,
            title = updated?.title ?: "New chat",
            answer = answer,
            records = records,
            chainOk = chainOk,
            narration = result?.narration.orEmpty(),
            error = result?.error?.message,
        )
    }

    private fun device(): DevicePort =
        if (config.hasBridge) {
            val bridge = BridgeClient(
                baseUrl = config.bridgeUrl,
                token = config.bridgeToken,
                refresh = {
                    val refresh = config.bridgeRefresh
                    if (refresh.isBlank()) {
                        null
                    } else {
                        runCatching { BridgeClient(config.bridgeUrl, "").refreshSession(refresh) }
                            .getOrNull()
                            ?.let { session ->
                                config.setSession(session.token, session.refresh)
                                io.log("bridge token refreshed")
                                io.send(Protocol.session(session.token, session.refresh))
                                session.token
                            }
                    }
                },
            )
            AdbDevice(bridge, clock)
        } else {
            hostDevice
        }

    private fun model(): ModelPort =
        if (config.hasModel && !forceStub) {
            ModelFactory().create(
                provider = config.modelProvider,
                endpoint = config.modelBaseUrl,
                apiKey = config.modelKey,
                modelName = config.modelName,
            )
        } else {
            StubModel()
        }
}

/** Emits each sealed record as it happens; the chain still lives in the inner recorder. */
private class EmittingRecorder(
    private val inner: RunRecorder,
    private val onRecord: (Int, RunRecord) -> Unit,
) : RunRecorder by inner {
    private var index = 0

    override suspend fun append(draft: RunRecordDraft): RunRecord {
        val record = inner.append(draft)
        onRecord(index, record)
        index += 1
        return record
    }
}
