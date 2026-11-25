package com.hopa.app.di

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.hopa.agent.action.ActionExecutor
import com.hopa.agent.action.ApprovalPolicy
import com.hopa.agent.decision.DecisionRuntime
import com.hopa.app.BuildConfig
import com.hopa.app.link.push.PushTokenFetch
import com.hopa.app.link.push.FirebaseToken
import com.hopa.app.link.session.BackendLaunchName
import com.hopa.app.link.remote.ProcessedTaskStore
import com.hopa.app.link.remote.RemoteRunRequest
import com.hopa.app.link.remote.RemoteTaskRunner
import com.hopa.app.link.session.BackendSession
import com.hopa.app.runtime.RemoteRuns
import com.hopa.app.service.AppVisibility
import com.hopa.app.service.Notifier
import com.hopa.app.service.PairingService
import com.hopa.app.service.RunService
import com.hopa.app.service.ScreenCaptureRequester
import com.hopa.app.service.ScreenCaptureService
import com.hopa.approval.UiApprovalGateway
import com.hopa.capabilities.accessibility.tree.AccessibilityDevice
import com.hopa.capabilities.system.AndroidClock
import com.hopa.capabilities.system.AndroidPackageCatalog
import com.hopa.capabilities.system.AndroidSystemPort
import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.ports.DevicePort
import com.hopa.data.database.HopaDatabase
import com.hopa.data.store.DataStoreSettingsRepository
import com.hopa.data.store.DbConversationStore
import com.hopa.data.store.DbDecisionVoteSink
import com.hopa.data.store.DbRunRecorder
import com.hopa.data.store.KeystoreSecretStore
import com.hopa.decision.ActionClass
import com.hopa.decision.DecisionCoordinator
import com.hopa.decision.DecisionMode
import com.hopa.decision.DecisionRegistry
import com.hopa.decision.DecisionSelector
import com.hopa.decision.LayerMetadata
import com.hopa.decision.classifier.IntentClassifier
import com.hopa.decision.graph.GraphCatalog
import com.hopa.decision.graph.GraphStepSource
import com.hopa.decision.graph.HandGraphSource
import com.hopa.decision.laix.LaixDecisionLayer
import com.hopa.decision.rules.RulesDecisionLayer
import com.hopa.feature.capabilities.CapabilitiesDependencies
import com.hopa.feature.conversations.ChatSyncOutcome
import com.hopa.feature.chat.ChatDependencies
import com.hopa.feature.conversations.ConversationsDependencies
import com.hopa.feature.easy.EasyDependencies
import com.hopa.feature.history.ActivityDependencies
import com.hopa.feature.history.HistoryDependencies
import com.hopa.feature.history.RecipesDependencies
import com.hopa.feature.launchpad.LaunchpadDependencies
import com.hopa.feature.memory.MemoryDependencies
import com.hopa.feature.power.PowerDependencies
import com.hopa.feature.profiles.ProfilesDependencies
import com.hopa.feature.runs.RunsDependencies
import com.hopa.feature.settings.PairingDependencies
import com.hopa.feature.settings.SettingsDependencies
import com.hopa.feature.settings.SurfaceDependencies
import com.hopa.feature.execution.ExecutionDependencies
import com.hopa.feature.skills.SkillsDependencies
import com.hopa.feature.usage.UsageDependencies
import com.hopa.inference.choice.ProviderChoiceRules
import com.hopa.inference.client.ModelFactory
import com.hopa.observation.source.ScreenSourceDevice
import com.hopa.runlog.record.RunRecordFactory
import com.hopa.stores.AppSettings
import com.hopa.stores.ConversationStore
import com.hopa.stores.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@Singleton
class AppContainer @Inject constructor(@ApplicationContext context: Context) : ChatDependencies, ConversationsDependencies,
    ActivityDependencies, MemoryDependencies, SkillsDependencies, UsageDependencies,
    SettingsDependencies, PairingDependencies, SurfaceDependencies, ProfilesDependencies,
    HistoryDependencies, RecipesDependencies, RunsDependencies,
    EasyDependencies, PowerDependencies, LaunchpadDependencies, CapabilitiesDependencies,
    ExecutionDependencies, LocalModelHost {
    override val context: Context = context.applicationContext
    override val localModels: com.hopa.engine.llama.LocalModelStore =
        com.hopa.engine.llama.AndroidLocalModelStore(context)

    /** The optional tree ranker's weights and download state. */
    override val treeRanker: com.hopa.mmbert.MmBertInstaller =
        com.hopa.mmbert.MmBertInstaller(context)

    @Volatile
    private var treeScorerCache: com.hopa.contracts.model.ActionScorer? = null

    /**
     * The tree ranker, opened on first use and kept for the process.
     *
     * It is intentionally lazy and swallow-on-failure: a missing or broken file
     * means the phone simply has no tree rung, not a crash in the loop.
     */
    fun treeScorer(): com.hopa.contracts.model.ActionScorer? {
        val file = com.hopa.mmbert.MmBertModel.file(context)
        treeScorerCache?.let { return it }
        if (!file.isFile) return null
        return synchronized(this) {
            treeScorerCache ?: runCatching {
                val started = System.currentTimeMillis()
                com.hopa.mmbert.MmBertScorer.open(context, file).also {
                    android.util.Log.i(
                        "HopaTree",
                        "ranker opened in ${System.currentTimeMillis() - started} ms",
                    )
                }
            }.onFailure {
                android.util.Log.w("HopaTree", "ranker failed to open", it)
            }.getOrNull()?.also { treeScorerCache = it }
        }
    }

    override val ramGb: Int
        get() = run {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val info = android.app.ActivityManager.MemoryInfo()
            manager.getMemoryInfo(info)
            (info.totalMem / 1_073_741_824L).toInt()
        }

    override val freeBytes: Long
        get() = context.filesDir.usableSpace

    override val settings: SettingsRepository = DataStoreSettingsRepository(
        context = context,
        secrets = KeystoreSecretStore(context),
    )

    /** The catalogue id of the model that answers on-device turns; empty = newest. */
    @Volatile
    private var selectedModel: String = ""

    init {
        com.hopa.privacy.TurnLog.attach(
            com.hopa.privacy.TurnLogFile(context),
        )
        // Follow the picked model so the engine's file and the receipt's name
        // can never disagree, without blocking the first turn on DataStore.
        kotlinx.coroutines.CoroutineScope(
            kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.Default,
        ).launch {
            settings.settings.collect { current -> selectedModel = current.activeModelId }
        }
    }

    private val database = HopaDatabase.build(context)
    override val conversations: ConversationStore = DbConversationStore(database)
    /**
     * The tables this client uses. A stored bundle wins over the bundled
     * snapshot; the file store falls back to it on any problem. `knowledge` is a
     * getter, so a bundle accepted between turns applies on the next one.
     */
    private val bundledKnowledge = com.hopa.data.catalog.AssetCatalogSource(context)
    val knowledgeStore: com.hopa.catalog.store.FileCatalogStore =
        com.hopa.catalog.store.FileCatalogStore(
            directory = java.io.File(context.filesDir, "knowledge"),
            fallback = bundledKnowledge.current(),
        )
    val knowledgeSource: com.hopa.catalog.store.CatalogSource = knowledgeStore
    override val knowledge: com.hopa.catalog.store.CatalogSnapshot get() = knowledgeSource.current()
    override val selectedConversation = MutableStateFlow<String?>(null)
    override val runGate = com.hopa.runtime.RunGate()
    /** The last wireless-pairing answer, shown on the Act page. */
    override val pairingStatus = MutableStateFlow<String?>(null)
    /**
     * Goals handed to the chat from outside (a deep link, a profile home).
     * A queue, not a slot: two links in a row must both run, and the second
     * must reach the parallel runner while the first holds the main turn.
     */
    override val pendingGoals = kotlinx.coroutines.channels.Channel<String>(
        kotlinx.coroutines.channels.Channel.UNLIMITED,
    )
    /** A file shared into the app, waiting in the composer. */
    override val pendingAttachment = MutableStateFlow<com.hopa.contracts.chat.Attachment?>(null)
    override val pendingNotice = MutableStateFlow<String?>(null)
    /** Work that must outlive an Activity, such as a one-shot launch pairing. */
    val appScope = kotlinx.coroutines.CoroutineScope(
        kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.IO,
    )
    /** The last launch-pairing outcome, shown on the Backend card. */
    override val backendNotice = MutableStateFlow<String?>(null)
    val intake = com.hopa.share.AttachmentIntake(context)
    override val packages = AndroidPackageCatalog(context)
    override val recorder = DbRunRecorder(database.runRecordDao())
    override val runHistory = com.hopa.data.store.DbRunHistory(database.runHistoryDao())
    val pendingApprovals = com.hopa.data.store.DbPendingApprovalStore(
        database.pendingApprovalDao(),
    )
    override val memory = com.hopa.data.store.DbMemoryStore(database.memoryDao())
    override val skills = com.hopa.data.store.DbSkillStore(database.skillDao())
    val clock = AndroidClock()

    /**
     * Which layer decides, and whether the others vote. Both are replaced as a
     * whole before a turn starts, so no step sees half of a new setting.
     */
    @Volatile
    private var decisionMode: DecisionMode = DecisionMode.Off

    @Volatile
    private var shadowDecisions = false

    /** Use these decision settings for the steps of the turns that start now. */
    override fun useDecisions(mode: String, shadow: Boolean) {
        decisionMode = DecisionMode.parse(mode)
        shadowDecisions = shadow
    }

    override fun stopTurn() {
        runGate.cancel()
        localEngine.cancel()
    }

    override suspend fun onDeviceModelName(): String {
        val file = localModelFile() ?: return "on-device"
        val id = file.name.substringBeforeLast('-', "")
        val name = com.hopa.inference.local.LocalModelCatalogue.models
            .firstOrNull { it.id == id }
            ?.name
            ?: id.ifBlank { "on-device" }
        val version = file.name
            .substringAfterLast('-', "")
            .removeSuffix(".gguf")
        return if (version.isBlank()) name else "$name ($version)"
    }

    /** The model directory: one file per catalogue id, named `<id>-<hash>.gguf`. */
    private fun modelDir(): java.io.File = java.io.File(context.filesDir, "models")

    /**
     * The file that answers an on-device turn.
     *
     * The picked id wins; without one (a fresh install) the newest file does, so
     * the engine and the receipt always name the same file.
     */
    private fun localModelFile(): java.io.File? {
        val files = modelDir().listFiles()
            ?.filter { it.isFile && it.name.endsWith(".gguf") }
            .orEmpty()
        if (selectedModel.isNotBlank()) {
            files.firstOrNull { it.name.startsWith("${selectedModel}-") }?.let { return it }
        }
        return files.maxByOrNull { it.lastModified() }
    }

    private val decisionVotes: DbDecisionVoteSink by lazy {
        DbDecisionVoteSink(database.decisionVoteDao(), clock) { decisionMode }
    }

    /** The layers this build ships; a new adapter is one entry here. */
    private val decisionRegistry: DecisionRegistry =
        DecisionRegistry(listOf(RulesDecisionLayer(), LaixDecisionLayer()))

    /**
     * A layer applies only to reading the screen. A change keeps the model and
     * the approval policy; a payment keeps the gate no matter what is selected.
     */
    val decisions: DecisionRuntime by lazy {
        DecisionRuntime(
            coordinator = DecisionCoordinator(decisionRegistry),
            mode = { decisionMode },
            shadow = { shadowDecisions },
            sink = decisionVotes,
            applies = { actionClass ->
                actionClass == ActionClass.READ && decisionMode !is DecisionMode.Off
            },
        )
    }

    /** Canonical commands that need no model at all. */
    val commands: IntentClassifier = IntentClassifier()

    /** Hand-written graphs for a few known apps; a miss goes to the model. */
    val graphs: GraphStepSource = HandGraphSource(GraphCatalog.load())

    override val decisionLayers: List<LayerMetadata>
        get() = decisionRegistry.all().map { it.metadata }

    override val graphPaths: List<String>
        get() = GraphCatalog.summary()

    override fun graphTarget(goal: String): com.hopa.decision.graph.GraphTarget? = graphs.target(goal)

    override fun activeDecision(actionClass: ActionClass): String =
        DecisionSelector(decisionRegistry).select(decisionMode, actionClass).layer?.metadata?.id
            ?: "model"
    /**
     * The gate settings, replaced as a whole when they change. The executor
     * reads one snapshot per step, so a turn that starts while Settings is being
     * saved cannot see half of the new list.
     */
    @Volatile
    private var gatePolicy = ApprovalPolicy()

    /** Use these settings for the turns that start now. */
    override fun useGate(trustedApps: Collection<String>, autonomous: Boolean) {
        gatePolicy = ApprovalPolicy(autonomous = autonomous, trustedApps = trustedApps)
    }

    val approval = UiApprovalGateway(pendingApprovals)
    val factory = RunRecordFactory(clock)
    val device = AccessibilityDevice(context)
    override val voice = com.hopa.capabilities.voice.VoiceRecorder(context)
    val speaker = com.hopa.capabilities.voice.Speaker(context)
    /** Goals that run at the same time, each on its own hidden display. */
    val runner by lazy { com.hopa.app.runtime.ParallelRunner(this) }

    /** Why the last hidden-display start failed; empty when it worked. */
    override var lastBackgroundError: String = ""
        private set


    /**
     * The app's one gateway link. Pairing and the activity life cycle reach it
     * through here; [remoteRunner] is attached below as its delivery handler.
     */
    val backend: BackendSession by lazy {
        BackendSession(
            settings = settings,
            pairingFactory = { url -> com.hopa.backend.pairing.BackendPairing(url) },
            linkFactory = { credentials, name, version, pushToken, refresh ->
                com.hopa.backend.link.BackendClient(
                    credentials = { credentials },
                    pushToken = pushToken,
                    refresh = refresh,
                    deviceName = name,
                    appVersion = version,
                )
            },
            deviceName = Build.MODEL,
            appVersion = BuildConfig.VERSION_NAME,
            // Without google-services.json Firebase is never initialized, so
            // there is nothing to ask and no token to wait for.
            pushTokenFetch = {
                FirebaseApp.getApps(context).isNotEmpty() && PushTokenFetch.load()
            },
        )
    }

    /** The surface stack for the person's screenPath setting, shared by chat and remote runs. */
    override val surfaces: suspend (AppSettings) -> ScreenSourceDevice = { Surfaces.resolve(this, it) }

    /** Task ids the gateway delivered, so a redelivery inside a day is skipped. */
    private val processedTasks by lazy { ProcessedTaskStore.open(context) }

    /**
     * A task delivered by the gateway runs on the configured surface and answers
     * on the wake socket. One at a time, so two deliveries never fight over the
     * screen.
     */
    val remoteRunner by lazy {
        RemoteTaskRunner(
            deviceId = { backend.deviceId },
            link = { backend.currentLink() },
            processed = processedTasks,
            settings = { settings.settings.first() },
            surfaces = { current -> surfaces(current) },
            screen = { current -> Surfaces.state(this, current) },
            runGate = runGate,
            foreground = { AppVisibility.foreground },
            startService = { startRunServiceInternal() },
            stopService = { stopRunServiceInternal() },
            postApproval = { Notifier.postApproval(context) },
            releaseSurface = { Surfaces.release() },
            run = { request: RemoteRunRequest -> RemoteRuns.execute(this, request) },
            taskStarted = { backend.taskStarted() },
            taskFinished = { backend.taskFinished() },
        )
    }

    /**
     * P4: a PC action can ask this phone to approve it. The same sheet as a
     * local run is used, and the answer travels back on the gateway socket.
     */
    val remoteApproval by lazy {
        com.hopa.app.link.remote.RemoteApprovalRunner(
            deviceId = { backend.deviceId },
            link = { backend.currentLink() },
            ask = approval::ask,
            sign = approvalSigner::sign,
            foreground = { AppVisibility.foreground },
            postApproval = { Notifier.postApproval(context) },
            taskStarted = { backend.taskStarted() },
            taskFinished = { backend.taskFinished() },
        )
    }

    init {
        // A delivered task runs on the surface the person configured. An
        // approval request is different: it only shows the question and sends
        // the answer back, so it must not claim the screen or run a turn.
        backend.onTask = { task -> remoteRunner.handle(task) }
        backend.onApproval = { task -> remoteApproval.handle(task) }
        // A diagnostic is plaintext and not goal-bearing; the session acks it
        // regardless. Nothing here reads or logs the body (trace/id only).
        backend.onDiagnostic = { }
    }

    private fun startRunServiceInternal() {
        val intent = android.content.Intent(context, RunService::class.java)
        ContextCompat.startForegroundService(context, intent)
    }

    private fun stopRunServiceInternal() {
        val intent = android.content.Intent(context, RunService::class.java)
        runCatching { context.stopService(intent) }
    }

    /** The hidden background display: one helper process, one loopback port. */
    val displayToken = com.hopa.capabilities.display.client.DisplayToken(context)
    override val shell = com.hopa.capabilities.display.client.ShellClient(displayToken.value)

    /**
     * Wireless debugging inside the app: pair once with the code Android shows,
     * then adbd gives this app shell and no PC is needed.
     */
    val wireless = com.hopa.capabilities.display.client.WirelessShell(context)

    /**
     * A device on the background display, or null when no helper can be reached.
     * The supervisor starts one when nothing answers and reports why when it
     * cannot, so a turn never drives a socket that only looks connected.
     */
    override suspend fun backgroundDevice(): DevicePort? =
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val status = helper.ensure()
            if (status !is com.hopa.capabilities.display.client.HelperStatus.Running) {
                lastBackgroundError = (status as? com.hopa.capabilities.display.client.HelperStatus.Failed)
                    ?.reason
                    .orEmpty()
                    .ifBlank { "the hidden screen is not running" }
                return@withContext null
            }
            val metrics = context.resources.displayMetrics
            val device = com.hopa.capabilities.display.client.ShellDisplayDevice(shell, context)
            if (device.start(metrics.widthPixels, metrics.heightPixels, metrics.densityDpi)) {
                lastBackgroundError = ""
                device
            } else {
                lastBackgroundError = device.error.ifBlank { "the helper refused a display" }
                null
            }
        }

    /**
     * One owner for the helper's life. `connect` heals a stale socket on its own
     * (it pings first), and `start` asks adbd, then the paired PC.
     */
    override val helper = com.hopa.capabilities.display.client.HelperSupervisor(
        ping = { shell.connect() },
        start = { startHelperOnPhone() },
        stop = { shell.close() },
        pause = { kotlinx.coroutines.delay(it) },
    )
    override val helperStatus = helper.status

    /** Ask the phone's own adbd first; fall back to the paired PC. */
    private suspend fun startHelperOnPhone(): Boolean {
        val startedHere = runCatching { wireless.connectAndStartHelper(displayToken.value) }
            .getOrDefault("")
            .contains("ready")
        return startedHere || startHelperThroughBridge()
    }

    /** Pair with this phone's own adbd, then start the helper with that shell. */
    override suspend fun pairWireless(address: String, code: String): String =
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val host = address.substringBefore(':').trim()
            val port = address.substringAfter(':', "").trim().toIntOrNull()
            if (host.isEmpty() || port == null) {
                return@withContext "Use the address Android shows: ip:port"
            }
            val paired = wireless.pair(host, port, code)
            if (!paired.startsWith("Paired")) {
                return@withContext paired
            }
            val started = wireless.connectAndStartHelper(displayToken.value)
            if (started.contains("ready") && shell.connect()) {
                "Wireless shell is ready; the hidden screen can be used"
            } else {
                started
            }
        }

    /** Ask the paired PC to start the helper on the phone as shell. */
    private suspend fun startHelperThroughBridge(): Boolean {
        val current = settings.settings.first()
        if (current.bridgeUrl.isBlank()) {
            return false
        }
        val token = settings.bridgeToken()
        if (token.isBlank()) {
            return false
        }
        return runCatching {
            com.hopa.bridge.session.BridgeClient(current.bridgeUrl, token)
                .startHelper(token = displayToken.value)
            true
        }.getOrDefault(false)
    }

    /**
     * One engine for the process: the file is resolved per turn, so importing or
     * deleting a model takes effect without a restart.
     */
    private val localEngine: com.hopa.engine.llama.LlamaEngine = com.hopa.engine.llama.LlamaEngine(
        pathProvider = { localModelFile()?.absolutePath },
        thermalStatus = {
            (context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager)
                .currentThermalStatus
        },
    )

    /** Free the model's memory when Android is short or the app is in the background. */
    fun releaseLocalModel() {
        localEngine.release()
    }

    override val modelFactory: ModelFactory = ModelFactory(localEngine = localEngine)

    override val localTokens: kotlinx.coroutines.flow.Flow<String> = localEngine.tokens

    val model = SettingsModelPort(settings, modelFactory, ProviderChoiceRules())
    /** The last rung: the API model, used only when the turn allows it. */
    val cloudModel: ModelPort = CloudModelPort(settings, modelFactory)
    /** Shared by the settings screen's "Test the model" button. */

    /** A bridge-backed device when Settings has an address and a token. */
    suspend fun bridgedDevice(): DevicePort? {
        val current = settings.settings.first()
        if (!current.useBridge || current.bridgeUrl.isBlank()) {
            return null
        }
        val token = settings.bridgeToken()
        if (token.isBlank()) {
            return null
        }
        val client = com.hopa.bridge.session.BridgeClient(
            baseUrl = current.bridgeUrl,
            token = token,
            refresh = {
                val saved = settings.bridgeRefresh()
                if (saved.isBlank()) {
                    null
                } else {
                    runCatching {
                        com.hopa.bridge.session.BridgeClient(
                            current.bridgeUrl,
                            "",
                        ).refreshSession(saved)
                    }.getOrNull()?.let { session ->
                        settings.setBridgeToken(session.token)
                        settings.setBridgeRefresh(session.refresh)
                        session.token
                    }
                }
            },
        )
        return com.hopa.bridge.device.AdbDevice(client, clock)
    }

    /**
     * Bring the chat back after a run that happened in another app. Android may
     * refuse a background activity start; the caller posts a notification too, so
     * a refusal still leaves a way in.
     */
    override fun bringToFront() {
        val intent = android.content.Intent(context, com.hopa.app.MainActivity::class.java)
            .addFlags(
                android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                    android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        runCatching { context.startActivity(intent) }
    }

    /** Read a reply aloud: the PC voice when a bridge is configured, else TTS. */
    override suspend fun speak(text: String): Boolean {
        val current = settings.settings.first()
        val token = settings.bridgeToken()
        if (current.bridgeUrl.isNotBlank() && token.isNotBlank()) {
            val wav = runCatching {
                com.hopa.bridge.session.BridgeClient(current.bridgeUrl, token).speak(text)
            }.getOrNull()
            if (wav != null) {
                return speaker.play(wav)
            }
        }
        return speaker.speak(text)
    }

    /** Speech to text through the PC bridge; null when no bridge is configured. */
    override suspend fun transcribe(wav: ByteArray): String? {
        val current = settings.settings.first()
        if (current.bridgeUrl.isBlank()) {
            return null
        }
        val token = settings.bridgeToken()
        if (token.isBlank()) {
            return null
        }
        return com.hopa.bridge.session.BridgeClient(current.bridgeUrl, token)
            .transcribe(wav)
    }

    /** The conversation half of the bridge, when one is configured. */
    private suspend fun chatSync(): com.hopa.app.link.sync.ChatSync? {
        val current = settings.settings.first()
        if (!current.useBridge || current.bridgeUrl.isBlank()) {
            return null
        }
        val token = settings.bridgeToken()
        if (token.isBlank()) {
            return null
        }
        return com.hopa.app.link.sync.ChatSync(
            conversations = conversations,
            transport = com.hopa.bridge.chat.BridgeChatTransport(
                com.hopa.bridge.session.BridgeClient(current.bridgeUrl, token),
            ),
        )
    }

    override suspend fun syncChats(): ChatSyncOutcome? {
        val sync = chatSync() ?: return null
        val report = sync.run()
        return ChatSyncOutcome(adopted = report.adopted, tombstoned = report.tombstoned)
    }

    override val backendState: StateFlow<com.hopa.backend.link.BackendState>
        get() = backend.state

    override val backendTask: StateFlow<com.hopa.backend.link.BackendTaskState>
        get() = backend.task

    override suspend fun connectShell(): Boolean =
        runCatching { shell.connect() }.getOrDefault(false)

    override fun notificationsAllowed(): Boolean = Notifier.permissionGranted(context)

    override fun postTestNotification(): Boolean = Notifier.postTest(context)

    override suspend fun pairGateway(link: com.hopa.backend.pairing.PairingLink): String =
        backend.pair(link).fold(
            onSuccess = { "Gateway paired; this phone can receive tasks" },
            onFailure = { error ->
                "Gateway: ${error.message ?: error::class.simpleName}"
            },
        )

    override suspend fun disconnectGateway(): String {
        runCatching { backend.disconnect() }
        return "Disconnected; the pairing is kept"
    }

    override fun backendToken(): String? = FirebaseToken.current()

    override fun fcmAvailable(): Boolean = FirebaseApp.getApps(context).isNotEmpty()

    override fun backendName(): String = BackendLaunchName.value

    /** Signs this phone's approval answers (ADR-0032); the key is created on first use. */
    val approvalSigner by lazy { com.hopa.app.link.remote.ApprovalSigner(settings) }

    override suspend fun approvalKeyFingerprint(): String = approvalSigner.fingerprint()

    override fun pairWirelessFromScreen() {
        PairingService.start(context, PairingService.MODE_AUTO)
    }

    override fun pairWirelessWaiting() {
        PairingService.start(context, PairingService.MODE_WAIT)
    }

    override fun requestScreenCapture() {
        ScreenCaptureRequester.request()
    }

    override fun stopScreenCapture() {
        ScreenCaptureService.stop(context)
    }

    override val pendingApproval: StateFlow<com.hopa.contracts.approval.ApprovalRequest?>
        get() = approval.pending

    override val tasks: StateFlow<List<com.hopa.contracts.task.TaskItem>>
        get() = runner.tasks

    override fun resolveApproval(allow: Boolean) {
        approval.resolve(allow)
    }

    override fun canStartTask(): Boolean = runner.canStart()

    override fun startTask(goal: String) {
        runner.start(goal)
    }

    override fun dismissTask(id: String) {
        runner.dismiss(id)
    }

    override suspend fun deleteAttachment(attachment: com.hopa.contracts.chat.Attachment) {
        intake.delete(attachment)
    }

    override fun planRequest(
        goal: String,
        runId: String,
        traceId: String,
    ): com.hopa.agent.turn.TurnRequest = runs.planRequest(goal, runId, traceId)

    override suspend fun request(
        goal: String,
        device: com.hopa.observation.source.ScreenSourceDevice,
        settings: com.hopa.stores.AppSettings,
        runId: String,
        traceId: String,
        history: List<com.hopa.contracts.model.ModelMessage>,
    ): com.hopa.agent.turn.TurnRequest =
        runs.request(goal, device, settings, runId, traceId, history)

    override suspend fun runTurn(
        request: com.hopa.agent.turn.TurnRequest,
        isCancelled: () -> Boolean,
    ): com.hopa.agent.turn.TurnOutcome = runs.run(request, isCancelled)

    override fun releaseSurfaces() {
        Surfaces.release()
    }

    override fun isForeground(): Boolean = AppVisibility.foreground

    override fun postAnswer(text: String) {
        Notifier.postAnswer(context, text)
    }

    override fun startRunService() = startRunServiceInternal()

    override fun stopRunService() = stopRunServiceInternal()

    /** One executor per device path, sharing the gate snapshot, approval and recorder. */
    fun executorFor(device: DevicePort): ActionExecutor = ActionExecutor(
        device = device,
        browser = null,
        system = AndroidSystemPort(context),
        sandbox = null,
        policy = { gatePolicy },
        approval = approval,
        recorder = recorder,
        factory = factory,
        clock = clock,
    )

    /** Recipes that were replayed before; a matching goal runs without the model. */
    override val recipes by lazy { com.hopa.agent.recipe.RecipeStore(java.io.File(context.filesDir, "recipes.txt")) }

    /** The one path from a goal to an answer: chat, parallel runs and deliveries. */
    val runs by lazy { com.hopa.app.runtime.RunCoordinator(this) }

    /** Asks the backend for a newer knowledge bundle; a failure keeps the copy. */
    val knowledgeUpdater by lazy {
        com.hopa.app.link.sync.CatalogUpdater(backend, knowledgeStore)
    }
}
