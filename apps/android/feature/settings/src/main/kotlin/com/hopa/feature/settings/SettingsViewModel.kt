package com.hopa.feature.settings

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import androidx.lifecycle.viewModelScope
import com.hopa.capabilities.accessibility.state.AccessibilityState
import com.hopa.stores.AppSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The screen state for settings. The work lives in four classes that each own
 * one concern - model, pairing, surface, preferences - so this class only
 * merges their answers into [SettingsUiState].
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val container: SettingsDependencies,
    pairingDependencies: PairingDependencies,
    surfaceDependencies: SurfaceDependencies,
) : ViewModel() {
    private val modelSettings = ModelSettings(container.settings, container.modelFactory)
    private val pairingSettings = PairingSettings(pairingDependencies)
    private val surfaceSettings = SurfaceSettings(surfaceDependencies)
    private val preferences = PreferencesSettings(container.settings)

    private val _state = MutableStateFlow(SettingsUiState())
    val state: StateFlow<SettingsUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { reload() }
        // The gateway link and the last delivered task change while this screen
        // is open, so the card reads them live instead of on a hidden refresh.
        viewModelScope.launch {
            container.backendState.collect { backend ->
                _state.update { it.copy(backendState = backend) }
            }
        }
        viewModelScope.launch {
            container.backendTask.collect { task ->
                _state.update { it.copy(backendTask = task) }
            }
        }
        // A launch pairing runs without this screen; its refusal or failure is
        // left in the container for the card to show here.
        viewModelScope.launch {
            container.backendNotice.collect { notice ->
                if (notice != null) {
                    _state.update { it.copy(backendStatus = notice) }
                }
            }
        }
        // Screen access is an event: the service pushes bind and unbind, so the
        // phone-access pill follows without a timer. One read first, because the
        // flow starts empty and must not say "off" about a working service.
        viewModelScope.launch {
            AccessibilityState.refresh(container.context)
            AccessibilityState.state.collect { binding ->
                _state.update { current ->
                    current.copy(
                        phoneAccess = phoneAccess(current.settings.accessibilityAllowed, binding.enabled, binding.connected),
                    )
                }
            }
        }
        // The helper's life belongs to the supervisor; this screen follows its
        // state instead of pinging the socket every few seconds.
        viewModelScope.launch {
            container.helperStatus.collect { status ->
                _state.update {
                    it.copy(
                        backgroundRunning =
                            status is com.hopa.capabilities.display.client.HelperStatus.Running,
                    )
                }
            }
        }
    }

    private fun phoneAccess(allowed: Boolean, enabled: Boolean, bound: Boolean): Boolean =
        com.hopa.runtime.ScreenAccess.available(allowed = allowed, enabled = enabled, bound = bound)

    fun save(
        provider: String,
        endpoint: String,
        model: String,
        key: String,
        notifyAnswers: Boolean,
        bridgeUrl: String,
        bridgeKey: String,
        useBridge: Boolean,
    ) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, saved = false, error = null) }
            runCatching {
                modelSettings.save(
                    provider, endpoint, model, key, notifyAnswers,
                    bridgeUrl, bridgeKey, useBridge,
                )
            }.onSuccess { note ->
                _state.update { it.copy(saved = true, notice = note) }
            }.onFailure { error ->
                _state.update { it.copy(error = error.message ?: "Could not save") }
            }
            reload()
            _state.update { it.copy(busy = false) }
        }
    }

    fun testModel(
        provider: String,
        endpoint: String,
        model: String,
        key: String,
        notifyAnswers: Boolean,
        bridgeUrl: String,
        bridgeKey: String,
        useBridge: Boolean,
    ) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, modelTest = "Testing\u2026", error = null) }
            val result = modelSettings.test(
                provider, endpoint, model, key, notifyAnswers,
                bridgeUrl, bridgeKey, useBridge,
            )
            reload()
            _state.update { it.copy(busy = false, modelTest = result.message, saved = result.ok) }
        }
    }

    fun setTone(value: String) {
        viewModelScope.launch {
            preferences.setTone(value)
            reload()
        }
    }

    /** The model picker on How HOPA acts: the provider, without leaving the page. */
    fun selectProvider(value: String) {
        viewModelScope.launch {
            container.settings.update { current ->
                // "Server" covers a cloud provider and a machine on the network;
                // the endpoint decides which, and the stored choice is kept when
                // it is one of the two.
                val provider = when (value) {
                    "server" -> when {
                        current.provider == "openai" || current.provider == "lan" -> current.provider
                        current.endpoint.startsWith("http://") -> "lan"
                        else -> "openai"
                    }
                    else -> value
                }
                current.copy(provider = provider)
            }
            reload()
        }
    }

    /** Which installed file answers; the engine and the receipt read the same id. */
    fun selectLocalModel(id: String) {
        viewModelScope.launch {
            container.settings.update {
                it.copy(provider = "on-device", activeModelId = id)
            }
            reload()
        }
    }

    fun setVision(value: Boolean) {
        viewModelScope.launch {
            surfaceSettings.setVision(value)
            reload()
        }
    }

    fun setTrusted(packageName: String, trusted: Boolean) {
        viewModelScope.launch {
            preferences.setTrusted(packageName, trusted)
            reload()
        }
    }

    fun setReplaySkills(value: Boolean) {
        viewModelScope.launch {
            preferences.setReplaySkills(value)
            reload()
        }
    }

    fun setCloudFallback(value: Boolean) {
        viewModelScope.launch {
            preferences.setCloudFallback(value)
            reload()
        }
    }

    fun setPlanFirst(value: Boolean) {
        viewModelScope.launch {
            preferences.setPlanFirst(value)
            reload()
        }
    }

    /** off, auto, or a layer id; the same words the decision mode parses. */
    fun setDecisionMode(value: String) {
        viewModelScope.launch {
            preferences.setDecisionMode(value)
            reload()
        }
    }

    fun setShadowDecisions(value: Boolean) {
        viewModelScope.launch {
            preferences.setShadowDecisions(value)
            reload()
        }
    }

    fun setInstantCommands(value: Boolean) {
        viewModelScope.launch {
            preferences.setInstantCommands(value)
            reload()
        }
    }

    /** auto, model or graph; the same words the turn reads. */
    fun setStepSource(value: String) {
        viewModelScope.launch {
            preferences.setStepSource(value)
            reload()
        }
    }

    /** The framed picture or the cut-out object; see MascotAppearance. */
    fun setMascotFramed(value: Boolean) {
        viewModelScope.launch {
            preferences.setMascotFramed(value)
            reload()
        }
    }

    fun setNotifications(value: Boolean) {
        viewModelScope.launch {
            preferences.setNotifications(value)
            reload()
        }
    }

    /** auto, background, onscreen or bridge; the same words the core enum uses. */
    fun setScreenPath(value: String) {
        viewModelScope.launch {
            _state.update { it.copy(bridgeStatus = null, screenCheck = emptyList()) }
            surfaceSettings.setScreenPath(value)
            reload()
        }
    }

    /** Re-read access, the helper and the saved mode after another page changed them. */
    fun refresh() {
        viewModelScope.launch { reload() }
    }

    fun setChattiness(value: String) {
        viewModelScope.launch {
            preferences.setChattiness(value)
            reload()
        }
    }

    fun testNotification() {
        if (!container.notificationsAllowed()) {
            _state.update {
                it.copy(notice = "Notifications are off in Android settings")
            }
            return
        }
        val sent = container.postTestNotification()
        _state.update {
            it.copy(
                notice = if (sent) {
                    "Test notification sent"
                } else {
                    "Could not show a notification"
                },
            )
        }
    }

    /**
     * Say, step by step, what works right now. The person should never have to
     * guess whether phone access, the helper or the bridge is the missing piece.
     */
    fun runScreenCheck() {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, screenCheck = emptyList()) }
            val checks = surfaceSettings.runScreenCheck()
            _state.update { it.copy(busy = false, screenCheck = checks) }
        }.invokeOnCompletion { _state.update { it.copy(busy = false) } }
    }

    /** Pair with this phone's own adbd; no PC needed after this succeeds. */
    fun pairWireless(address: String, code: String) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val message = pairingSettings.pairWireless(address, code)
            _state.update {
                it.copy(
                    busy = false,
                    bridgeStatus = message,
                    backgroundRunning = if (message.contains("is ready", ignoreCase = true)) {
                        true
                    } else {
                        it.backgroundRunning
                    },
                )
            }
        }
    }

    /** Read the code from Android's pairing dialog instead of asking for it. */
    fun pairWirelessFromScreen() {
        pairingSettings.pairWirelessFromScreen()
    }

    /** Wait for a dialog the person opens, then read its code and pair. */
    fun pairWirelessWaiting() {
        pairingSettings.pairWirelessWaiting()
    }

    /** Start the hidden-screen helper on the phone, using the paired PC bridge. */
    fun startBackgroundHelper() {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val message = pairingSettings.startBackgroundHelper()
            _state.update {
                it.copy(
                    busy = false,
                    bridgeStatus = message,
                    backgroundRunning = if (message == "Hidden screen is ready") {
                        true
                    } else {
                        it.backgroundRunning
                    },
                )
            }
        }
    }

    fun pairBridge(url: String, code: String) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val message = pairingSettings.pairBridge(url, code)
            if (message.startsWith("Bridge paired")) {
                reload()
            }
            _state.update { it.copy(busy = false, bridgeStatus = message) }
        }
    }

    /**
     * Pair the gateway. The field takes the whole `hopa://pair…` link or a bare
     * session next to the address on screen; nothing is guessed when both are
     * missing.
     */
    fun pair(url: String, text: String) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, backendStatus = null) }
            val message = pairingSettings.pair(url, text)
            reload()
            _state.update { it.copy(busy = false, backendStatus = message) }
        }
    }

    /** Close the socket but keep the stored identity, so the next open reconnects. */
    fun disconnectBackend() {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, backendStatus = null) }
            val message = pairingSettings.disconnectBackend()
            reload()
            _state.update { it.copy(busy = false, backendStatus = message) }
        }
    }

    /**
     * Ask Android once, for this screen opening or the app coming back from the
     * settings page. The service pushes every later change.
     */
    fun refreshScreenAccess() {
        surfaceSettings.refreshScreenAccess()
    }

    fun testBridge(url: String, token: String) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val message = pairingSettings.testBridge(url, token)
            _state.update { it.copy(busy = false, bridgeStatus = message) }
        }
    }

    /** Only the helper's liveness; cheap enough to run while the page is open. */
    fun refreshBackground() {
        viewModelScope.launch {
            val running = surfaceSettings.refreshBackground()
            _state.update {
                if (it.backgroundRunning == running) it else it.copy(backgroundRunning = running)
            }
        }
    }

    private fun layerTitle(id: String): String = when (id) {
        "rules" -> "Rules"
        "laix" -> "LAIX"
        else -> id.replaceFirstChar { it.uppercase() }
    }

    private suspend fun reload() {
        val settings: AppSettings = container.settings.settings.first()
        val background = withContext(Dispatchers.IO) {
            container.connectShell()
        }
        val model = modelSettings.snapshot()
        val pairing = pairingSettings.snapshot(settings)
        val phoneAccess = surfaceSettings.phoneAccess(settings)
        val layers = container.decisionLayers.map { metadata ->
            DecisionLayerInfo(
                id = metadata.id,
                title = layerTitle(metadata.id),
                detail = "${metadata.version} · ${metadata.latency.name.lowercase()} · " +
                    "up to ${metadata.decidesUpTo.name.lowercase()} actions",
                summary = metadata.summary,
                howTo = when (metadata.status) {
                    com.hopa.decision.LayerStatus.DEFAULT ->
                        "It decides the steps it is allowed to; the other layers keep voting."
                    com.hopa.decision.LayerStatus.SHADOW ->
                        "It votes on every step and is recorded, but it does not decide yet."
                    com.hopa.decision.LayerStatus.EXPERIMENTAL ->
                        "Available to try: it votes in the log but does not decide."
                    com.hopa.decision.LayerStatus.RETIRED ->
                        "No longer in this build; choosing it falls back to Automatic."
                },
            )
        }
        val active = mapOf(
            "read" to container.activeDecision(com.hopa.decision.ActionClass.READ),
            "change" to container.activeDecision(com.hopa.decision.ActionClass.CHANGE),
            "dangerous" to container.activeDecision(com.hopa.decision.ActionClass.DANGEROUS),
        )
        val installed = container.localModels.installed().map { model ->
            val name = com.hopa.inference.local.LocalModelCatalogue.models
                .firstOrNull { it.id == model.id }
                ?.name
                ?: model.id
            ModelOption(id = model.id, label = name, bytes = model.bytes)
        }
        _state.update {
            it.copy(
                settings = settings,
                decisionLayers = layers,
                decisionActive = active,
                graphPaths = container.graphPaths,
                installedModels = installed,
                key = model.key,
                keySaved = model.keySaved,
                bridgeKey = pairing.bridgeKey,
                backgroundRunning = background,
                backendUrl = pairing.backendUrl,
                backendDeviceId = pairing.backendDeviceId,
                backendName = pairing.backendName,
                backendToken = pairing.backendToken,
                fcmAvailable = pairing.fcmAvailable,
                providerState = model.providerState,
                phoneAccess = phoneAccess,
                error = model.error ?: it.error,
            )
        }
    }
}
