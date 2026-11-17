package com.hopa.app.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.FirebaseApp
import com.hopa.app.backend.FirebaseToken
import com.hopa.app.backend.ScreenAccess
import com.hopa.app.di.AppContainer
import com.hopa.capabilities.accessibility.AccessibilityState
import com.hopa.capabilities.accessibility.HopaAccessibilityService
import com.hopa.net.bridge.BridgeClient
import com.hopa.net.llm.ProviderState
import com.hopa.net.llm.ProviderStateResolver
import com.hopa.engine.model.ModelMessage
import com.hopa.engine.model.ModelRequest
import com.hopa.stores.AppSettings
import java.io.IOException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

class SettingsViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val resolver = ProviderStateResolver()
    private val _state = MutableStateFlow(SettingsUiState())
    val state: StateFlow<SettingsUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { reload() }
        // The gateway link and the last delivered task change while this screen
        // is open, so the card reads them live instead of on a hidden refresh.
        viewModelScope.launch {
            container.backend.state.collect { backend ->
                _state.update {
                    it.copy(
                        backendState = backend,
                        backendToken = FirebaseToken.current(),
                        fcmAvailable = FirebaseApp.getApps(container.context).isNotEmpty(),
                    )
                }
            }
        }
        viewModelScope.launch {
            container.backend.task.collect { task ->
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
    }

    fun save(
        provider: String,
        endpoint: String,
        model: String,
        key: String,
        notifyAnswers: Boolean,
        webEnabled: Boolean,
        bridgeUrl: String,
        bridgeKey: String,
        useBridge: Boolean,
    ) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, saved = false, error = null) }
            runCatching {
                persist(provider, endpoint, model, key, notifyAnswers, webEnabled, bridgeUrl, bridgeKey, useBridge)
            }.onSuccess { note ->
                _state.update { it.copy(saved = true, notice = note) }
            }.onFailure { error ->
                _state.update { it.copy(error = error.message ?: "Could not save") }
            }
            _state.update { it.copy(busy = false) }
        }
    }

    /**
     * Write every field on the screen, including the key, then read the
     * settings back. The read-back is the point: a key that only exists in the
     * text field used to look configured while the next screen saw nothing.
     */
    private suspend fun persist(
        provider: String,
        endpoint: String,
        model: String,
        key: String,
        notifyAnswers: Boolean,
        webEnabled: Boolean,
        bridgeUrl: String,
        bridgeKey: String,
        useBridge: Boolean,
    ): String? {
        // A key the user just typed turns the demo off. Leaving the provider on
        // "stub" while a key is present kept chat on the demo model.
        val trimmedProvider = provider.trim()
        val trimmedEndpoint = endpoint.trim()
        val effectiveProvider = when {
            key.isBlank() -> trimmedProvider.ifBlank { "stub" }
            trimmedProvider.isBlank() || trimmedProvider.equals("stub", true) ->
                if (trimmedEndpoint.startsWith("http://")) "lan" else "openai"
            else -> trimmedProvider
        }
        container.settings.update {
            it.copy(
                provider = effectiveProvider,
                endpoint = trimmedEndpoint,
                model = model.trim(),
                notifyAnswers = notifyAnswers,
                webEnabled = webEnabled,
                bridgeUrl = bridgeUrl.trim(),
                useBridge = useBridge,
            )
        }
        if (key.isNotBlank()) {
            container.settings.setModelKey(key.trim())
        }
        if (bridgeKey.isNotBlank()) {
            container.settings.setBridgeToken(bridgeKey.trim())
        }
        reload()
        if (key.isNotBlank() && _state.value.key.isBlank()) {
            throw IOException("the key did not reach the Keystore")
        }
        return if (effectiveProvider != trimmedProvider) {
            "Saved as $effectiveProvider: a key turns the demo off"
        } else {
            null
        }
    }

    /**
     * Save first, then ask the saved model one short question. Testing with the
     * typed key alone told the user the model worked while nothing was stored.
     */
    fun testModel(
        provider: String,
        endpoint: String,
        model: String,
        key: String,
        notifyAnswers: Boolean,
        webEnabled: Boolean,
        bridgeUrl: String,
        bridgeKey: String,
        useBridge: Boolean,
    ) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, modelTest = "Testing\u2026", error = null) }
            val message = runCatching {
                persist(provider, endpoint, model, key, notifyAnswers, webEnabled, bridgeUrl, bridgeKey, useBridge)
                val current = container.settings.settings.first()
                val storedKey = container.settings.modelKey()
                val state = ProviderStateResolver()
                    .resolve(current.provider, current.endpoint, storedKey)
                if (state == ProviderState.DEMO) {
                    throw IOException("no key is stored, so this is still the demo model")
                }
                val client = container.modelFactory.create(
                    provider = current.provider,
                    endpoint = current.endpoint,
                    apiKey = storedKey,
                    modelName = current.model,
                )
                val reply = withTimeout(30_000) {
                    client.complete(
                        ModelRequest(
                            messages = listOf(ModelMessage("user", "Reply with the single word: ready")),
                            maxTokens = 32,
                        ),
                    )
                }
                "Model answered: ${reply.text.trim().take(80)}"
            }.getOrElse { error ->
                "Model failed: ${error.message ?: error::class.simpleName}"
            }
            _state.update { it.copy(busy = false, modelTest = message, saved = message.startsWith("Model answered")) }
        }
    }

    fun setTone(value: String) {
        viewModelScope.launch {
            container.settings.update { it.copy(tone = value) }
            reload()
        }
    }

    fun setVision(value: Boolean) {
        viewModelScope.launch {
            container.settings.update { it.copy(vision = value) }
            reload()
        }
        // Below API 30 there is no accessibility screenshot, so turning vision on
        // asks for MediaProjection consent once; API 30+ needs no extra grant.
        if (value &&
            android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.R &&
            !com.hopa.capabilities.display.MediaProjectionCapture.isActive
        ) {
            com.hopa.app.service.ScreenCaptureRequester.request()
        } else if (!value &&
            com.hopa.capabilities.display.MediaProjectionCapture.isActive
        ) {
            com.hopa.app.service.ScreenCaptureService.stop(container.context)
        }
    }

    fun setTrusted(packageName: String, trusted: Boolean) {
        if (packageName.isBlank()) {
            return
        }
        viewModelScope.launch {
            container.settings.update { current ->
                current.copy(
                    trustedApps = if (trusted) {
                        current.trustedApps + packageName
                    } else {
                        current.trustedApps - packageName
                    },
                )
            }
            reload()
        }
    }

    fun setReplaySkills(value: Boolean) {
        viewModelScope.launch {
            container.settings.update { it.copy(replaySkills = value) }
            reload()
        }
    }

    fun setPlanFirst(value: Boolean) {
        viewModelScope.launch {
            container.settings.update { it.copy(planFirst = value) }
            reload()
        }
    }

    fun setNotifications(value: Boolean) {
        viewModelScope.launch {
            container.settings.update { it.copy(notifyAnswers = value) }
            reload()
        }
    }

    /** auto, background, onscreen or bridge; the same words the core enum uses. */
    fun setScreenPath(value: String) {
        viewModelScope.launch {
            _state.update { it.copy(bridgeStatus = null, screenCheck = emptyList()) }
            container.settings.update {
                it.copy(
                    screenPath = value,
                    // Selecting the computer turns the bridge on. Going back to
                    // the phone leaves the bridge configured: chat sync and voice
                    // still use it, and only the tap driver changes.
                    useBridge = if (value == "bridge") true else it.useBridge,
                )
            }
            reload()
        }
    }

    /** Re-read access, the helper and the saved mode after another page changed them. */
    fun refresh() {
        viewModelScope.launch { reload() }
    }

    fun setChattiness(value: String) {
        viewModelScope.launch {
            container.settings.update { it.copy(chattiness = value) }
            reload()
        }
    }

    fun testNotification() {
        if (!com.hopa.app.service.Notifier.permissionGranted(container.context)) {
            _state.update {
                it.copy(notice = "Notifications are off in Android settings")
            }
            return
        }
        val sent = com.hopa.app.service.Notifier.postTest(container.context)
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
            val checks = mutableListOf<ScreenCheck>()
            val current = container.settings.settings.first()
            val path = current.screenPath
            val onBridge = path == "bridge"
            val service = HopaAccessibilityService.instance
            val enabled = AccessibilityState.isEnabled(container.context)

            checks += when {
                onBridge -> ScreenCheck(
                    "screen",
                    "Screen access is not needed with My computer",
                    ok = true,
                    info = true,
                )

                !current.accessibilityAllowed -> ScreenCheck(
                    "screen",
                    "Screen access is paused by you - tap Fix to resume it",
                    ok = false,
                    action = "Fix",
                )

                enabled && service != null -> ScreenCheck(
                    "screen",
                    "HOPA can see your screen",
                    ok = true,
                )

                enabled -> ScreenCheck(
                    "screen",
                    "Screen access is on but not answering - tap Fix to open it",
                    ok = false,
                    action = "Fix",
                )

                else -> ScreenCheck(
                    "screen",
                    "Screen access is off - tap Fix, then turn on HOPA",
                    ok = false,
                    action = "Fix",
                )
            }

            val socket = if (onBridge || path == "onscreen") {
                false
            } else {
                withContext(Dispatchers.IO) { container.shell.connect() }
            }
            checks += when {
                onBridge -> ScreenCheck(
                    "background",
                    "Hidden screen is not used with My computer",
                    ok = true,
                    info = true,
                )

                path == "onscreen" -> ScreenCheck(
                    "background",
                    "Hidden screen is not used with Your screen",
                    ok = true,
                    info = true,
                )

                socket -> ScreenCheck("background", "Hidden screen is ready", ok = true)

                path == "auto" -> ScreenCheck(
                    "background",
                    "Hidden screen isn't running; your screen will be used",
                    ok = true,
                    info = true,
                )

                else -> ScreenCheck(
                    "background",
                    "Hidden screen isn't running - tap Set up, then pair once",
                    ok = false,
                    action = "Set up",
                )
            }

            if (socket) {
                // Android 16 lets apps publish typed functions; the shell sees them
                // through `cmd app_function`, which is a cleaner door than tapping.
                val listing = withContext(Dispatchers.IO) {
                    runCatching { container.shell.appFunctions("com.android.settings") }
                        .getOrNull()
                }
                val appFunctions = when {
                    listing == null -> "App functions: could not be checked"
                    listing.second.contains("Can't find service") ||
                        listing.second.contains("Unknown command") ->
                        "App functions: this Android does not offer them (needs 16)"
                    else -> "App functions: this Android supports them"
                }
                checks += ScreenCheck("appfn", appFunctions, ok = true, info = true)

                val device = runCatching { container.backgroundDevice() }.getOrNull()
                if (device == null) {
                    val why = container.lastBackgroundError.ifBlank { "no display" }
                    checks += ScreenCheck(
                        "tried",
                        "Hidden screen failed: $why",
                        ok = false,
                    )
                } else {
                    val opened = withContext(Dispatchers.IO) {
                        runCatching { device.launch("com.android.settings") }
                    }
                    withContext(Dispatchers.IO) {
                        runCatching { device.observe() }.getOrNull()
                    }
                    checks += if (opened.isSuccess) {
                        ScreenCheck("tried", "Tested it: Settings opened out of sight", ok = true)
                    } else {
                        ScreenCheck(
                            "tried",
                            "Test failed: ${opened.exceptionOrNull()?.message}",
                            ok = false,
                        )
                    }
                    runCatching {
                        (device as? com.hopa.capabilities.display.ShellDisplayDevice)?.stop()
                    }
                }
            }

            val token = container.settings.bridgeToken()
            val bridgeConfigured = current.bridgeUrl.isNotBlank() && token.isNotBlank()
            if (bridgeConfigured) {
                val health = withContext(Dispatchers.IO) {
                    runCatching {
                        com.hopa.net.bridge.BridgeClient(current.bridgeUrl, token).health()
                        true
                    }.getOrDefault(false)
                }
                checks += when {
                    health -> ScreenCheck("computer", "HOPA bridge is connected", ok = true)
                    onBridge -> ScreenCheck(
                        "computer",
                        "HOPA bridge is not answering - tap Fix",
                        ok = false,
                        action = "Fix",
                    )
                    else -> ScreenCheck(
                        "computer",
                        "HOPA bridge is not answering (not needed for This phone)",
                        ok = true,
                        info = true,
                    )
                }
            } else if (onBridge) {
                checks += ScreenCheck(
                    "computer",
                    "HOPA bridge isn't set up - tap Fix",
                    ok = false,
                    action = "Fix",
                )
            } else {
                checks += ScreenCheck(
                    "computer",
                    "HOPA bridge isn't set up (not needed for This phone)",
                    ok = true,
                    info = true,
                )
            }

            checks += ScreenCheck(
                "mode",
                "Apps will open: ${pathLabel(path).lowercase()}",
                ok = true,
                info = true,
            )
            _state.update { it.copy(busy = false, screenCheck = checks) }
        }.invokeOnCompletion { _state.update { it.copy(busy = false) } }
    }

    /** Pair with this phone's own adbd; no PC needed after this succeeds. */
    fun pairWireless(address: String, code: String) {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val message = container.pairWireless(address, code)
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
        com.hopa.app.service.PairingService.start(
            container.context,
            com.hopa.app.service.PairingService.MODE_AUTO,
        )
    }

    /** Wait for a dialog the person opens, then read its code and pair. */
    fun pairWirelessWaiting() {
        com.hopa.app.service.PairingService.start(
            container.context,
            com.hopa.app.service.PairingService.MODE_WAIT,
        )
    }

    /** Start the hidden-screen helper on the phone, using the paired PC bridge. */
    fun startBackgroundHelper() {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val current = container.settings.settings.first()
            val token = container.settings.bridgeToken()
            val message = when {
                current.bridgeUrl.isBlank() -> "Bridge: set an address first"
                token.isBlank() -> "Bridge: pair first, then start the helper"
                else -> runCatching {
                    val output = BridgeClient(current.bridgeUrl, token)
                        .startHelper(token = container.displayToken.value)
                    container.shell.close()
                    if (container.shell.connect()) {
                        "Hidden screen is ready"
                    } else {
                        "Helper started but did not answer: ${output.take(120)}"
                    }
                }.getOrElse { error -> "Hidden screen: ${error.message}" }
            }
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
            if (url.isBlank() || code.isBlank()) {
                _state.update { it.copy(bridgeStatus = "Bridge: address and pair code first") }
                return@launch
            }
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val message = runCatching {
                val session = BridgeClient(url, "").pair(code.trim())
                container.settings.setBridgeToken(session.token)
                container.settings.setBridgeRefresh(session.refresh)
                reload()
                "Bridge paired; the token is in the Keystore"
            }.getOrElse { error -> "Bridge: ${error.message}" }
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
            val link = PairInput.normalise(text, url.trim())
            if (link == null) {
                _state.update {
                    it.copy(backendStatus = "Gateway: paste a pairing link or a session with an address")
                }
                return@launch
            }
            _state.update { it.copy(busy = true, backendStatus = null) }
            val message = container.backend.pair(link).fold(
                onSuccess = { "Gateway paired; this phone can receive tasks" },
                onFailure = { error ->
                    "Gateway: ${error.message ?: error::class.simpleName}"
                },
            )
            reload()
            _state.update { it.copy(busy = false, backendStatus = message) }
        }
    }

    /** Close the socket but keep the stored identity, so the next open reconnects. */
    fun disconnectBackend() {
        viewModelScope.launch {
            _state.update { it.copy(busy = true, backendStatus = null) }
            runCatching { container.backend.disconnect() }
            reload()
            _state.update {
                it.copy(busy = false, backendStatus = "Disconnected; the pairing is kept")
            }
        }
    }

    /** Re-read the saved identity and the FCM registration on demand. */
    fun refresh() {
        viewModelScope.launch { reload() }
    }

    /**
     * Android binds the accessibility service a moment after the app resumes.
     * The pill reads this snapshot, so it is refreshed on resume and polled
     * instead of staying at the value from when the screen first opened.
     */
    fun refreshScreenAccess() {
        val current = _state.value.settings
        val available = ScreenAccess.available(
            allowed = current.accessibilityAllowed,
            enabled = AccessibilityState.isEnabled(container.context),
            bound = HopaAccessibilityService.instance != null,
        )
        _state.update { it.copy(phoneAccess = available) }
    }

    fun testBridge(url: String, token: String) {
        viewModelScope.launch {
            if (url.isBlank()) {
                _state.update { it.copy(bridgeStatus = "Bridge: set an address first") }
                return@launch
            }
            _state.update { it.copy(busy = true, bridgeStatus = null) }
            val effective = token.ifBlank {
                runCatching { container.settings.bridgeToken() }.getOrDefault("")
            }
            val message = runCatching {
                val client = BridgeClient(url, effective)
                client.health()
                val who = client.whoami()
                val devices = who["devices"]?.jsonArray
                    ?.joinToString { it.jsonPrimitive.content }
                val nodes = client.observe()["nodes"]?.jsonArray?.size ?: 0
                "Bridge ok: ${devices ?: "paired"}, $nodes nodes"
            }.getOrElse { error -> "Bridge: ${error.message}" }
            _state.update { it.copy(busy = false, bridgeStatus = message) }
        }
    }

    /** Only the helper's liveness; cheap enough to run while the page is open. */
    fun refreshBackground() {
        viewModelScope.launch {
            val running = withContext(Dispatchers.IO) {
                runCatching {
                    container.shell.connect() && container.shell.ping()
                }.getOrDefault(false)
            }
            _state.update {
                if (it.backgroundRunning == running) it else it.copy(backgroundRunning = running)
            }
        }
    }

    private suspend fun reload() {
        val settings: AppSettings = container.settings.settings.first()
        val background = withContext(Dispatchers.IO) {
            runCatching { container.shell.connect() }.getOrDefault(false)
        }
        val key = container.settings.modelKey()
        val keySaved = container.settings.hasModelKey()
        val bridgeKey = container.settings.bridgeToken()
        _state.update {
            it.copy(
                settings = settings,
                key = key,
                keySaved = keySaved,
                bridgeKey = bridgeKey,
                backgroundRunning = background,
                backendUrl = settings.backendUrl,
                backendDeviceId = settings.backendDeviceId,
                backendName = com.hopa.app.backend.BackendLaunchName.value,
                backendToken = FirebaseToken.current(),
                fcmAvailable = FirebaseApp.getApps(container.context).isNotEmpty(),
                providerState = resolver.resolve(settings.provider, settings.endpoint, key),
                phoneAccess = ScreenAccess.available(
                    allowed = settings.accessibilityAllowed,
                    enabled = AccessibilityState.isEnabled(container.context),
                    bound = HopaAccessibilityService.instance != null,
                ),
                error = if (keySaved && key.isBlank()) {
                    "The saved key cannot be read on this phone; paste it again"
                } else {
                    it.error
                },
            )
        }
    }
}
