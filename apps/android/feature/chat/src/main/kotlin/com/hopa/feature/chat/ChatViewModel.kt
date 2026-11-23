package com.hopa.feature.chat

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import androidx.lifecycle.viewModelScope
import com.hopa.feature.chat.ChatDependencies
import com.hopa.contracts.model.ModelMessage
import com.hopa.observation.produce.ScreenPath
import com.hopa.contracts.chat.Attachment
import com.hopa.contracts.chat.AttachmentRules
import com.hopa.contracts.chat.ChatMessage
import com.hopa.contracts.task.TaskItem
import com.hopa.stores.AppSettings
import com.hopa.agent.turn.TurnOutcome
import com.hopa.agent.turn.TurnSource
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.hopa.privacy.TurnLog
import com.hopa.privacy.TurnLogEntry
import com.hopa.runtime.RunSource

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val container: ChatDependencies,
) : ViewModel() {
    private val _state = MutableStateFlow(ChatUiState())
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    /** The queue beside the composer, and the switch the screen reads. */
    val tasks: StateFlow<List<TaskItem>> = container.tasks
    val settings: StateFlow<AppSettings> = container.settings.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AppSettings())

    init {
        viewModelScope.launch {
            container.localTokens.collect { piece ->
                if (_state.value.busy) {
                    _state.update { state -> state.copy(liveText = state.liveText + piece) }
                }
            }
        }
        // A goal handed over from the shell starts a turn on arrival; send()
        // marks the app busy before it returns, so the next queued goal is
        // routed to the parallel runner instead of replacing this one.
        viewModelScope.launch {
            for (goal in container.pendingGoals) {
                prefill(goal)
                send()
            }
        }
        viewModelScope.launch { load() }
        viewModelScope.launch {
            container.pendingApproval.collect { request ->
                _state.update { it.copy(pendingApproval = request) }
            }
        }
        viewModelScope.launch {
            container.pendingAttachment.collect { attachment ->
                if (attachment?.path != _state.value.attachment?.path) {
                    _state.update { it.copy(attachment = attachment) }
                }
            }
        }
        viewModelScope.launch {
            container.pendingNotice.collect { notice ->
                _state.update { it.copy(attachmentNotice = notice) }
            }
        }
        viewModelScope.launch {
            container.selectedConversation.collect { id ->
                if (id == null || id == _state.value.current?.id) {
                    return@collect
                }
                val all = container.conversations.all()
                val selected = all.firstOrNull { it.id == id } ?: return@collect
                _state.update {
                    it.copy(current = selected, conversations = all, options = emptyList())
                }
            }
        }
    }

    fun onInput(value: String) {
        _state.update { it.copy(input = value) }
    }

    /** A deep link or a shared selection lands in the composer, never sent. */
    fun prefill(text: String) {
        _state.update { it.copy(input = text.trim()) }
    }

    // ── Voice ─────────────────────────────────────────────────────────────────

    fun startVoice() {
        if (_state.value.busy || _state.value.recording) {
            return
        }
        if (!container.voice.hasPermission()) {
            _state.update { it.copy(voiceError = "Microphone permission is off") }
            return
        }
        if (!container.voice.start()) {
            _state.update { it.copy(voiceError = "Could not start the microphone") }
            return
        }
        _state.update { it.copy(recording = true, voiceError = null) }
    }

    fun stopVoice() {
        if (!_state.value.recording) {
            return
        }
        _state.update { it.copy(recording = false, transcribing = true) }
        viewModelScope.launch {
            val wav = runCatching { container.voice.stop() }.getOrNull()
            if (wav == null) {
                _state.update { it.copy(transcribing = false, voiceError = "Nothing was recorded") }
                return@launch
            }
            val result = runCatching { container.transcribe(wav) }
            val text = result.getOrNull()
            _state.update {
                it.copy(
                    transcribing = false,
                    input = text?.takeIf { value -> value.isNotBlank() } ?: it.input,
                    voiceError = when {
                        result.isFailure -> "Voice failed: ${result.exceptionOrNull()?.message}"
                        text == null -> "Connect the bridge to dictate"
                        text.isBlank() -> "I did not catch that"
                        else -> null
                    },
                )
            }
        }
    }

    fun dismissVoiceError() {
        _state.update { it.copy(voiceError = null) }
    }

    /** Read a reply through the PC voice or Android TTS. */
    fun speak(text: String) {
        if (text.isBlank()) {
            return
        }
        viewModelScope.launch { container.speak(text) }
    }

    // ── Conversation management ───────────────────────────────────────────────

    fun newChat() {
        viewModelScope.launch {
            val created = container.conversations.create()
            container.selectedConversation.value = created.id
            container.settings.update { it.copy(selectedConversation = created.id) }
            _state.update {
                it.copy(
                    current = created,
                    conversations = container.conversations.all(),
                    input = "",
                    error = null,
                    options = emptyList(),
                )
            }
        }
    }

    fun delete(id: String) {
        viewModelScope.launch {
            container.conversations.delete(id)
            load()
        }
    }

    fun rename(id: String, title: String) {
        viewModelScope.launch {
            container.conversations.rename(id, title)
            load()
        }
    }

    /** Remove the last exchange from the thread. */
    fun undoLast() {
        if (_state.value.busy) {
            return
        }
        val conversation = _state.value.current ?: return
        if (conversation.messages.size < 2) {
            return
        }
        viewModelScope.launch {
            container.conversations.dropLastExchange(conversation.id)
            val all = container.conversations.all()
            _state.update {
                it.copy(
                    current = all.firstOrNull { item -> item.id == conversation.id },
                    conversations = all,
                )
            }
        }
    }

    /** Re-run the last user goal without appending the message twice. */
    fun retryLast() {
        if (_state.value.busy) {
            return
        }
        val conversation = _state.value.current ?: return
        val lastUser = conversation.messages.lastOrNull { it.role == "user" } ?: return
        sendText(lastUser.text, appendUser = false)
    }

    // ── Send dispatch ─────────────────────────────────────────────────────────

    fun send() {
        val text = _state.value.input.trim()
        val attachment = _state.value.attachment
        if (text.isEmpty() && attachment == null) {
            return
        }
        if (_state.value.busy) {
            // The main turn is still going. A second goal goes to its own hidden
            // display instead of being dropped on the floor.
            if (text.isNotBlank() && container.canStartTask()) {
                container.startTask(text)
                _state.update { it.copy(input = "") }
            }
            return
        }
        sendText(text, attachment = attachment)
    }

    /** Drop the shared file before it is sent, and remove its bytes. */
    /** A finished task leaves the chip row. */
    fun dismissTask(id: String) {
        container.dismissTask(id)
    }

    fun discardAttachment() {
        val attachment = _state.value.attachment
        container.pendingAttachment.value = null
        container.pendingNotice.value = null
        _state.update { it.copy(attachment = null, attachmentNotice = null) }
        if (attachment != null) {
            viewModelScope.launch { container.deleteAttachment(attachment) }
        }
    }

    fun dismissAttachmentNotice() {
        container.pendingNotice.value = null
        _state.update { it.copy(attachmentNotice = null) }
    }

    fun sendOption(option: String) {
        sendText(option)
    }

    fun sendQuick(text: String) {
        sendText(text)
    }

    private var planApprovedFor = ""
    private var pendingGoal = ""

    /** The person read the plan; run exactly that goal now. */
    fun approvePlan() {
        val goal = pendingGoal
        val plan = _state.value.pendingPlan
        if (goal.isBlank() || plan == null) {
            return
        }
        planApprovedFor = goal
        _state.update { it.copy(pendingPlan = null) }
        // The message is already in the chat: the plan was read above it.
        sendText(goal, appendUser = false)
    }

    /** The stop button: the loop checks the gate, the native decode checks its flag. */
    fun stop() {
        container.stopTurn()
    }

    fun cancelPlan() {
        pendingGoal = ""
        _state.update { it.copy(pendingPlan = null) }
    }

    /** Keep the work as a reusable skill, so the next similar ask starts ahead. */
    fun saveSkill(goal: String, steps: List<String>) {
        if (goal.isBlank() || steps.isEmpty()) {
            return
        }
        viewModelScope.launch {
            val saved = runCatching {
                container.skills.add(
                    trigger = goal.take(80),
                    action = steps.joinToString("\n"),
                )
            }.isSuccess
            if (saved) {
                _state.update { it.copy(savedGoals = it.savedGoals + goal) }
            } else {
                _state.update { it.copy(error = "Could not save the skill.") }
            }
        }
    }

    fun resolveApproval(allow: Boolean) {
        container.resolveApproval(allow)
    }

    // ── Core send loop ────────────────────────────────────────────────────────

    /**
     * What is about to run, said before the first step. Empty means "the model",
     * where the screen already shows the configured model.
     */
    private fun liveLabelFor(goal: String, settings: AppSettings): String {
        if (goal.isBlank() || settings.stepSource == "model") {
            return ""
        }
        val target = runCatching { container.graphTarget(goal) }.getOrNull()
        return when {
            target != null -> "Anchors \u00B7 ${target.name}"
            settings.stepSource == "graph" -> "Anchors only"
            else -> ""
        }
    }

    private fun sendText(
        text: String,
        attachment: Attachment? = null,
        appendUser: Boolean = true,
    ) {
        val conversation = _state.value.current ?: return
        val body = text.ifBlank { attachment?.let(AttachmentRules::describe).orEmpty() }
        if (planApprovedFor.isNotEmpty() && planApprovedFor != body) {
            planApprovedFor = ""
        }
        _state.update {
            it.copy(
                input = "",
                busy = true,
                liveText = "",
                liveLabel = liveLabelFor(body, settings.value),
                error = null,
                options = emptyList(),
                attachment = null,
                attachmentNotice = null,
            )
        }
        container.pendingAttachment.value = null
        container.pendingNotice.value = null
        // A task delivered to the other device may hold the phone. Two loops on
        // one screen would fight over it and cancel each other.
        if (!container.runGate.claim(body, com.hopa.runtime.RunSource.CHAT)) {
            _state.update {
                it.copy(error = "HOPA is busy with a task from your other device", busy = false)
            }
            return
        }
        container.startRunService()
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            if (appendUser) appendUserMessage(conversation.id, body, attachment, now)
            val history = conversation.messages.map { ModelMessage(it.role, it.text) }
            val current = container.settings.settings.first()
            // A graph needs no plan: asking for steps to "open Wi-Fi
            // settings" is slower than following them, and the turn has the
            // same rule before its own plan gate.
            val graphTarget = if (current.stepSource == "model") {
                null
            } else {
                runCatching { container.graphTarget(body) }.getOrNull()
            }
            container.useGate(current.trustedApps.toList())
            container.useDecisions(current.decisionMode, current.shadowDecisions)
            val receiptModel = if (current.provider.equals("on-device", ignoreCase = true)) {
                runCatching { container.onDeviceModelName() }.getOrDefault("on-device")
            } else {
                listOf(current.provider, current.model).filter { it.isNotBlank() }.joinToString("/")
            }
            _state.update {
                it.copy(
                    onDevice = current.provider == "on-device",
                    receiptModel = receiptModel,
                    liveLabel = liveLabelFor(body, current),
                )
            }
            val preferred = ScreenPath.of(current.screenPath)

            // Plan-first gate: show the plan before anything is tapped. A plan
            // asks for steps, so no surface is opened and nothing is observed.
            if (current.planFirst && planApprovedFor != body && graphTarget == null) {
                val outcome = container.runTurn(
                    container.planRequest(
                        goal = body,
                        runId = "run-$now",
                        traceId = UUID.randomUUID().toString(),
                    ),
                )
                container.runGate.finish()
                container.stopRunService()
                if (outcome.pendingPlan.isEmpty()) {
                    _state.update {
                        it.copy(liveText = "", busy = false, error = outcome.error?.message ?: "No plan came back")
                    }
                } else {
                    pendingGoal = body
                    _state.update { it.copy(busy = false, pendingPlan = outcome.pendingPlan) }
                }
                return@launch
            }

            val device = container.surfaces(current)
            device.observe()
            val request = container.request(
                goal = body,
                device = device,
                settings = current,
                history = history,
                runId = "run-$now",
                traceId = UUID.randomUUID().toString(),
            )
            val outcome = try {
                container.runTurn(request) { container.runGate.isCancelled() }
            } finally {
                container.stopRunService()
                container.releaseSurfaces()
            }
            when (outcome.source) {
                TurnSource.PLAN -> Unit // handled above; a plan never reaches here
                TurnSource.UNAVAILABLE ->
                    handleNoDevice(outcome.surfaceError, preferred, conversation.id)
                TurnSource.RECIPE ->
                    recordReplay(outcome, body, conversation.id, now, preferred)
                TurnSource.MODEL, TurnSource.COMMAND, TurnSource.GRAPH ->
                    recordTurn(outcome, body, conversation.id, now, preferred, history)
            }
        }.invokeOnCompletion { container.runGate.finish() }
    }

    // ── sendText helpers ──────────────────────────────────────────────────────

    /** Posts a system message explaining why the action cannot proceed. */
    private suspend fun handleNoDevice(
        error: String,
        preferred: ScreenPath,
        conversationId: String,
    ) {
        container.runGate.finish()
        container.stopRunService()
        container.conversations.append(
            conversationId,
            ChatMessage(
                id = "m-${System.currentTimeMillis()}-screen",
                role = "assistant",
                text = "I cannot reach your apps: " +
                    error.take(180).ifBlank { "no screen answered" } +
                    ". " +
                    when (preferred) {
                        ScreenPath.BRIDGE ->
                            "Open Act and set up My computer, or choose This phone."
                        ScreenPath.BACKGROUND ->
                            "Open Act: start the hidden screen or turn on screen access."
                        else ->
                            "Open Act: turn on screen access, start the hidden " +
                                "screen, or choose My computer."
                    },
                timestamp = System.currentTimeMillis(),
            ),
        )
        val all = container.conversations.all()
        _state.update {
            it.copy(
                current = all.firstOrNull { item -> item.id == conversationId },
                conversations = all,
                busy = false,
            )
        }
    }

    /** The cheap path: a recipe ran, its final screen answered, this is the receipt. */
    private suspend fun recordReplay(
        outcome: TurnOutcome,
        body: String,
        conversationId: String,
        now: Long,
        preferred: ScreenPath,
    ) {
        container.runGate.finish()
        val replayed = outcome.replaySteps.size
        container.conversations.append(
            conversationId,
            ChatMessage(
                id = "m-${System.currentTimeMillis()}-replay",
                role = "assistant",
                text = outcome.answer,
                timestamp = System.currentTimeMillis(),
                proof = com.hopa.contracts.chat.MessageProof(
                    path = outcome.surfaceName,
                    executed = replayed,
                    verified = replayed,
                    tokens = outcome.usage.totalTokens,
                    millis = System.currentTimeMillis() - now,
                    steps = outcome.replaySteps,
                    fellBack = preferred == ScreenPath.AUTO &&
                        outcome.surfaceName == "accessibility",
                    knowledgeVersion = outcome.knowledgeVersion,
                    model = _state.value.receiptModel,
                    source = outcome.source.name.lowercase(),
                ),
            ),
        )
        runCatching {
            container.runHistory.record(
                at = System.currentTimeMillis(),
                goal = body,
                path = outcome.surfaceName,
                steps = replayed,
                tokens = outcome.usage.totalTokens,
                conversationId = conversationId,
            )
        }
        val shown = container.conversations.all()
        _state.update {
            it.copy(
                current = shown.firstOrNull { item -> item.id == conversationId },
                conversations = shown,
                busy = false,
            )
        }
    }

    /** Appends the user message to the DB and immediately reflects it in state. */
    private suspend fun appendUserMessage(
        conversationId: String,
        body: String,
        attachment: Attachment?,
        now: Long,
    ) {
        container.conversations.append(
            conversationId,
            ChatMessage(
                id = "m-$now-${UUID.randomUUID().toString().take(6)}",
                role = "user",
                text = body,
                timestamp = now,
                attachment = attachment,
            ),
        )
        // The store is the source of truth, but the screen reads state, so the
        // bubble must be published now or it waits until the answer arrives.
        val shown = container.conversations.all()
        _state.update {
            it.copy(
                current = shown.firstOrNull { item -> item.id == conversationId },
                conversations = shown,
            )
        }
    }

    /** Persists the turn result and publishes the final state to the UI. */
    private suspend fun recordTurn(
        result: TurnOutcome,
        body: String,
        conversationId: String,
        now: Long,
        preferred: ScreenPath,
        history: List<ModelMessage>,
    ) {
        val answer = result.answer
        val steps = result.records.map { record ->
            val target = record.action.app
                ?: record.action.ref
                ?: record.action.url
                ?: record.action.text?.take(40)
                ?: ""
            "${record.step}. ${record.action.kind}${if (target.isBlank()) "" else " $target"}"
        }
        val proof = com.hopa.contracts.chat.MessageProof(
            path = result.surfaceName,
            executed = result.executed,
            verified = result.verified,
            tokens = result.usage.totalTokens,
            millis = System.currentTimeMillis() - now,
            steps = steps,
            fellBack = preferred == ScreenPath.AUTO && result.surfaceName == "accessibility",
            knowledgeVersion = result.knowledgeVersion,
            model = _state.value.receiptModel,
            source = result.source.name.lowercase(),
        )
        container.conversations.append(
            conversationId,
            ChatMessage(
                id = "m-${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(6)}",
                role = "assistant",
                text = answer,
                timestamp = System.currentTimeMillis(),
                proof = proof.takeIf { it.executed > 0 },
            ),
        )
        val all = container.conversations.all()
        container.runGate.finish()
        runCatching {
            container.runHistory.record(
                at = System.currentTimeMillis(),
                goal = body,
                path = result.surfaceName,
                steps = steps.size,
                tokens = proof.tokens,
                conversationId = conversationId,
            )
        }
        com.hopa.privacy.TurnLog.add(
            com.hopa.privacy.TurnLogEntry(
                at = System.currentTimeMillis(),
                path = result.surfaceName,
                steps = steps.size,
                tokens = proof.tokens,
                charactersSent = history.sumOf { it.content.length } + body.length,
                goal = body.take(80),
            ),
        )
        _state.update {
            it.copy(
                current = all.firstOrNull { item -> item.id == conversationId },
                conversations = all,
                busy = false,
                error = result.error?.message,
                options = result.options,
            )
        }
        answerOutsideApp(answer)
    }

    // ── Misc helpers ──────────────────────────────────────────────────────────

    /**
     * A run happens inside another app, so the answer is invisible until the
     * person switches back. Try to bring HOPA forward and leave a notification in
     * case Android refuses a background activity start.
     */
    private suspend fun answerOutsideApp(text: String) {
        if (text.isBlank() || container.isForeground()) {
            return
        }
        val notify = runCatching { container.settings.settings.first().notifyAnswers }
            .getOrDefault(true)
        if (notify) {
            runCatching { container.postAnswer(text) }
        }
        container.bringToFront()
    }

    private suspend fun load() {
        val all = container.conversations.all()
        val savedId = container.settings.settings.first().selectedConversation
        val selectedId = savedId.ifBlank { container.selectedConversation.value }
        val current = all.firstOrNull { it.id == selectedId }
            ?: all.firstOrNull()
            ?: container.conversations.create().also {
                container.selectedConversation.value = it.id
            }
        container.selectedConversation.value = current.id
        container.settings.update { it.copy(selectedConversation = current.id) }
        _state.update {
            it.copy(
                conversations = container.conversations.all(),
                current = current,
                busy = false,
            )
        }
    }
}
