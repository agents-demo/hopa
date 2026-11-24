package com.hopa.sidecar.turn

import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.action.ApprovalPolicy
import com.hopa.agent.decision.model.ModelStepPolicy
import com.hopa.agent.goal.Checkpoint
import com.hopa.agent.loop.StepGate
import com.hopa.agent.plan.ModelPlanSource
import com.hopa.agent.recipe.RecipeStore
import com.hopa.agent.turn.TurnRequest
import com.hopa.agent.turn.TurnRunner
import com.hopa.decision.classifier.IntentClassifier
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
import com.hopa.stores.MemoryStore
import com.hopa.stores.SkillStore
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import com.hopa.sidecar.device.HostDevice
import com.hopa.sidecar.device.HostSystem
import com.hopa.sidecar.device.WindowsPathSelector
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.protocol.Stdio

/** What one turn produced, for the protocol and for `--turn`. */
class TurnEngine(
    private val io: Stdio,
    private val hostDevice: DevicePort,
    private val approval: ApprovalGateway,
    private val store: ChatStore,
    private val recordStore: RecordStore,
    private val config: RuntimeConfig,
    private val memory: MemoryStore,
    private val skills: SkillStore,
    private val recipes: RecipeStore,
    private val forceStub: Boolean = false,
    /** False in headless: no host is attached, so the prompt must not claim access. */
    private val deviceAttached: Boolean = true,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val clock = SystemClock()
    private val turnLock = Mutex()

    @Volatile
    private var cancelled = false

    /** The turn currently on the engine; cancel(id) must not hit another one. */
    @Volatile
    private var runningTurn: String? = null

    /**
     * Host and backend turns share one loop, one screen and one chat store, so
     * they must not interleave. The gate is held for the whole turn body; a
     * queued turn waits here rather than starting a second loop.
     */
    private val turnGate = Mutex()

    /** Ids waiting for [turnGate]; a cancel before the start is remembered. */
    private val queuedTurns: MutableSet<String> = ConcurrentHashMap.newKeySet()
    private val cancelledBeforeStart: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** A paused turn waits here; the takeover window owns the foreground. */
    private val takeovers: ConcurrentHashMap<String, CompletableDeferred<Boolean>> = ConcurrentHashMap()

    /**
     * Invoked next to `turn.end` with the turn id and its answer, so the
     * backend gateway can resume a `task.create` (R31). One turn at a time is
     * this engine's contract; the hook must not block.
     */
    @Volatile
    var onTurnEnd: ((id: String, answer: String) -> Unit)? = null

    /** Shutdown/no-id cancel: stops whatever turn is running. */
    @Synchronized
    fun cancel() {
        cancelled = true
        runningTurn?.let { takeovers.remove(it)?.complete(false) }
        io.log("turn cancelled by the user")
    }

    /** Pause the running turn and hand the foreground to the person. */
    @Synchronized
    fun pause() {
        val id = runningTurn ?: return
        takeovers[id] = CompletableDeferred()
        io.log("turn $id paused for takeover")
    }

    /** Resume after a takeover; the loop re-observes before the next decision. */
    @Synchronized
    fun resume() {
        val id = runningTurn ?: return
        takeovers.remove(id)?.complete(true)
        io.log("turn $id resumed after takeover")
    }

    /** Cancels only the named turn, so a backend task cannot stop a host turn. */
    @Synchronized
    fun cancel(id: String) {
        takeovers.remove(id)?.complete(false)
        if (runningTurn == id) {
            cancelled = true
            io.log("turn $id cancelled by the user")
            return
        }
        // The turn is still waiting for the gate. Keep the request so the turn
        // starts already cancelled instead of silently ignoring the user.
        if (queuedTurns.remove(id)) {
            cancelledBeforeStart += id
            io.log("turn $id cancelled before it started")
        }
    }

    @Synchronized
    private fun beginTurn(id: String) {
        queuedTurns.remove(id)
        cancelled = cancelledBeforeStart.remove(id)
        runningTurn = id
    }

    @Synchronized
    private fun finishTurn(id: String) {
        if (runningTurn == id) runningTurn = null
    }

    /**
     * The apps this PC can open, from the catalog's windows column. There is no
     * installed-app inventory here yet, so only entries we know how to start are
     * offered, and the prompt says a launch may still fail.
     */
    private fun windowsApps(): List<InstalledApp> = CatalogRoutes
        .targets(platform = "windows", knowledge = SidecarCatalog.value)
        .filter { it.kind == "app" && it.bundle.isNotEmpty() }
        .map { InstalledApp(packageName = it.bundle, label = it.display) }

    /** The window path: launch the turn, stream `step` events, finish with `turn.end`. */
    fun startTurn(
        id: String,
        goal: String,
        conversationId: String?,
        attachment: Attachment? = null,
        planApproved: Boolean = false,
        checkpoints: List<Checkpoint> = emptyList(),
    ) {
        queuedTurns += id
        scope.launch {
            runSerialized(id) {
                var lastAt = System.currentTimeMillis()
                val outcome = runTurn(
                    id,
                    goal,
                    conversationId,
                    attachment,
                    planApproved = planApproved,
                    checkpoints = checkpoints,
                ) { index, record ->
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
                        plan = outcome.plan,
                        checkpointsComplete = outcome.checkpointsComplete,
                        checkpointsMissing = outcome.checkpointsMissing,
                    ),
                )
                outcome.answer
            }
        }
    }

    /**
     * The one gate every turn goes through. Extracted so the serialization is
     * testable with fake turn bodies: the second body does not run until the
     * first has finished and released the gate.
     */
    internal suspend fun runSerialized(id: String, turn: suspend () -> String) {
        turnGate.withLock {
            beginTurn(id)
            try {
                guardedTurn(id, turn)
            } finally {
                cancelledBeforeStart.remove(id)
            }
        }
    }

    /**
     * Runs one turn and guarantees exactly one `onTurnEnd`, even when the turn
     * throws before it reaches `turn.end`. Extracted so the failure contract is
     * testable without a model or a host.
     */
    internal suspend fun guardedTurn(id: String, turn: suspend () -> String) {
        var ending: String? = null
        try {
            ending = turn()
        } catch (cancelledTurn: CancellationException) {
            ending = CANCELLED_ANSWER
            throw cancelledTurn
        } catch (failed: Exception) {
            // The failure text may quote the goal or model output; log the
            // turn id only and answer generically.
            io.log("turn $id failed before it ended")
            ending = FAILED_ANSWER
        } finally {
            finishTurn(id)
            ending?.let { answer -> notifyTurnEnd(id, answer) }
        }
    }

    /**
     * The one execution path. Serialised: a second turn waits for the first, so
     * two windows cannot interleave device actions or records. The window path
     * also holds [turnGate] so a cancelling host turn and a backend task cannot
     * start together.
     */
    suspend fun runTurn(
        id: String,
        goal: String,
        conversationId: String?,
        attachment: Attachment? = null,
        planApproved: Boolean = false,
        checkpoints: List<Checkpoint> = emptyList(),
        onRecord: ((Int, RunRecord) -> Unit)? = null,
    ): TurnOutcome = turnLock.withLock {
        val requested = conversationId?.takeIf { it.isNotBlank() }
        val existing = requested?.let { store.get(it) }
        if (requested != null && existing == null) {
            io.log("unknown conversation $requested; starting a new one")
        }
        val conversation = existing ?: store.create()
        val history = conversation.messages.map { ModelMessage(it.role, it.text) }
        store.append(conversation.id, "user", goal, attachment)
        // The goal may be private; it is persisted in the chat store, never logged.
        io.log("turn $id in ${conversation.id}")

        val device = device()
        val model = model()
        val buffer = InMemoryRunRecorder()
        val recorder = if (onRecord == null) buffer else EmittingRecorder(buffer, onRecord)
        val memoryText = memory.promptText()
        val skillText = skills.promptText()

        // The shared runner owns plan-first, recipe replay, the step loop and the
        // deadline. Windows supplies the ports and turns the outcome into a
        // conversation; it does not keep a second copy of the order.
        val runner = TurnRunner(
            steps = ModelStepPolicy(model),
            executorFor = { target ->
                val selector = if (config.hasBridge) null else WindowsPathSelector()
                val system = (target as? HostDevice)?.let { HostSystem(it) }
                ActionExecutor(
                    device = target,
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
            },
            recorder = recorder,
            clock = clock,
            recipes = recipes,
            plans = ModelPlanSource(model),
            commands = IntentClassifier(),
            knowledge = { SidecarCatalog.value },
        )
        val outcome = runCatching {
            runner.run(
                TurnRequest(
                    goal = goal,
                    device = device,
                    runId = "run-$id",
                    traceId = UUID.randomUUID().toString(),
                    history = history,
                    memory = memoryText,
                    skills = skillText,
                    installedApps = windowsApps(),
                    platform = "windows",
                    vision = config.vision,
                    phoneAccess = deviceAttached,
                    planFirst = config.planFirst,
                    planApproved = planApproved,
                    replay = config.replay,
                    instantCommands = config.instantCommands,
                    checkpoints = checkpoints,
                    useGraphs = false,
                    graphFallback = false,
                    cloudFallback = false,
                    timeoutMillis = 120_000,
                ),
                isCancelled = { cancelled },
                beforeStep = {
                    val gate = takeovers[id]
                    if (gate == null) {
                        StepGate.Proceed
                    } else if (gate.await()) {
                        StepGate.Refresh
                    } else {
                        StepGate.Stop
                    }
                },
            )
        }

        val result = outcome.getOrNull()
        val answer = result?.answer?.ifBlank { result.error?.message.orEmpty() }
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
            plan = result?.pendingPlan.orEmpty(),
            checkpointsComplete = result?.checkpoints?.complete,
            checkpointsMissing = result?.checkpoints?.missing?.map { it.anchor }.orEmpty(),
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
            ScriptedModel()
        }

    private fun notifyTurnEnd(id: String, answer: String) {
        try {
            onTurnEnd?.invoke(id, answer)
        } catch (failed: Exception) {
            // A broken backend hook must not lose a host turn that already ended.
            io.log("turn $id ended but its backend hook failed")
        }
    }

    private companion object {
        const val FAILED_ANSWER = "The sidecar failed before it could finish the turn."
        const val CANCELLED_ANSWER = "The turn was cancelled."
    }
}
