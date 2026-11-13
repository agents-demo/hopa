package com.hopa.app.di

import android.content.Context
import com.hopa.app.model.SettingsModelPort
import com.hopa.capabilities.device.UnavailableDevicePort
import com.hopa.capabilities.llm.ModelFactory
import com.hopa.capabilities.system.AndroidClock
import com.hopa.capabilities.system.AndroidPackageCatalog
import com.hopa.capabilities.system.AndroidSystemPort
import com.hopa.core.gate.ActionExecutor
import com.hopa.core.gate.ApprovalPolicy
import com.hopa.core.gate.SessionApprovalGateway
import com.hopa.core.loop.AgentLoop
import com.hopa.core.records.InMemoryRunRecorder
import com.hopa.core.records.RunRecordFactory
import com.hopa.data.secrets.KeystoreSecretStore
import com.hopa.data.sessions.ConversationStore
import com.hopa.data.sessions.InMemoryConversationStore
import com.hopa.data.settings.DataStoreSettingsRepository
import com.hopa.data.settings.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow

class AppContainer(context: Context) {
    val settings: SettingsRepository = DataStoreSettingsRepository(
        context = context,
        secrets = KeystoreSecretStore(context),
    )
    val conversations: ConversationStore = InMemoryConversationStore()
    val selectedConversation = MutableStateFlow<String?>(null)
    val packages = AndroidPackageCatalog(context)
    val recorder = InMemoryRunRecorder()
    val clock = AndroidClock()
    val policy = ApprovalPolicy()
    val factory = RunRecordFactory(clock)
    val device = UnavailableDevicePort()
    val executor = ActionExecutor(
        device = device,
        browser = null,
        system = AndroidSystemPort(context),
        sandbox = null,
        policy = policy,
        approval = SessionApprovalGateway(),
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
}
