package com.hopa.app.di

import android.content.Context
import com.hopa.app.model.SettingsModelPort
import com.hopa.capabilities.accessibility.AccessibilityDevice
import com.hopa.capabilities.llm.ModelFactory
import com.hopa.capabilities.system.AndroidClock
import com.hopa.capabilities.system.AndroidPackageCatalog
import com.hopa.capabilities.system.AndroidSystemPort
import com.hopa.core.gate.ActionExecutor
import com.hopa.core.gate.ApprovalPolicy
import com.hopa.app.gate.UiApprovalGateway
import com.hopa.core.loop.AgentLoop
import com.hopa.data.database.HopaDatabase
import com.hopa.data.records.RoomRunRecorder
import com.hopa.core.records.RunRecordFactory
import com.hopa.data.secrets.KeystoreSecretStore
import com.hopa.data.sessions.ConversationStore
import com.hopa.data.sessions.RoomConversationStore
import com.hopa.data.settings.DataStoreSettingsRepository
import com.hopa.data.settings.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first

class AppContainer(context: Context) {
    val context: Context = context.applicationContext
    val settings: SettingsRepository = DataStoreSettingsRepository(
        context = context,
        secrets = KeystoreSecretStore(context),
    )
    private val database = HopaDatabase.build(context)
    val conversations: ConversationStore = RoomConversationStore(database)
    val selectedConversation = MutableStateFlow<String?>(null)
    val busy = MutableStateFlow(false)
    val packages = AndroidPackageCatalog(context)
    val recorder = RoomRunRecorder(database.runRecordDao())
    val pendingApprovals = com.hopa.data.approvals.RoomPendingApprovalStore(
        database.pendingApprovalDao(),
    )
    val clock = AndroidClock()
    val policy = ApprovalPolicy()
    val approval = UiApprovalGateway(pendingApprovals)
    val factory = RunRecordFactory(clock)
    val device = AccessibilityDevice(context)
    val executor = ActionExecutor(
        device = device,
        browser = null,
        system = AndroidSystemPort(context),
        sandbox = null,
        policy = policy,
        approval = approval,
        recorder = recorder,
        factory = factory,
        clock = clock,
    )
    val model = SettingsModelPort(settings, ModelFactory())
    val loop = AgentLoop(
        model = model,
        device = device,
        executor = executor,
        recorder = recorder,
        clock = clock,
        webAvailable = false,
    )

    /** A bridge-backed device when Settings has an address and a token. */
    suspend fun bridgedDevice(): com.hopa.core.ports.DevicePort? {
        val current = settings.settings.first()
        if (!current.useBridge || current.bridgeUrl.isBlank()) {
            return null
        }
        val token = settings.bridgeToken()
        if (token.isBlank()) {
            return null
        }
        val client = com.hopa.capabilities.bridge.BridgeClient(
            baseUrl = current.bridgeUrl,
            token = token,
            refresh = {
                val saved = settings.bridgeRefresh()
                if (saved.isBlank()) {
                    null
                } else {
                    runCatching {
                        com.hopa.capabilities.bridge.BridgeClient(
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
        return com.hopa.capabilities.bridge.AdbDevice(client, clock)
    }

    /** The conversation half of the bridge, when one is configured. */
    suspend fun chatSync(): com.hopa.app.feature.sync.ChatSync? {
        val current = settings.settings.first()
        if (!current.useBridge || current.bridgeUrl.isBlank()) {
            return null
        }
        val token = settings.bridgeToken()
        if (token.isBlank()) {
            return null
        }
        return com.hopa.app.feature.sync.ChatSync(
            conversations = conversations,
            transport = com.hopa.capabilities.bridge.BridgeChatTransport(
                com.hopa.capabilities.bridge.BridgeClient(current.bridgeUrl, token),
            ),
        )
    }

    /** One loop per device path, sharing the model, recorder and gate. */
    fun loopFor(device: com.hopa.core.ports.DevicePort): AgentLoop = AgentLoop(
        model = model,
        device = device,
        executor = ActionExecutor(
            device = device,
            browser = null,
            system = AndroidSystemPort(context),
            sandbox = null,
            policy = policy,
            approval = approval,
            recorder = recorder,
            factory = factory,
            clock = clock,
        ),
        recorder = recorder,
        clock = clock,
        webAvailable = false,
    )
}
