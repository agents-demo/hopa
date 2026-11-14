package com.hopa.app.feature.chat

import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hopa.app.di.AppContainer
import com.hopa.core.gate.ApprovalRequest
import com.hopa.core.loop.TurnContext
import com.hopa.core.model.ModelMessage
import com.hopa.data.sessions.ChatMessage
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

class ChatViewModel(
    private val container: AppContainer,
) : ViewModel() {
    private val _state = MutableStateFlow(ChatUiState())
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch { load() }
        viewModelScope.launch {
            container.approval.pending.collect { request ->
                _state.update { it.copy(pendingApproval = request) }
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

    fun select(id: String) {
        viewModelScope.launch {
            val all = container.conversations.all()
            val selected = all.firstOrNull { it.id == id } ?: return@launch
            container.selectedConversation.value = id
            container.settings.update { it.copy(selectedConversation = id) }
            _state.update { it.copy(current = selected, conversations = all, options = emptyList()) }
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

    fun send() {
        val text = _state.value.input.trim()
        if (text.isEmpty() || _state.value.busy) {
            return
        }
        sendText(text)
    }

    fun sendOption(option: String) {
        sendText(option)
    }

    fun sendQuick(text: String) {
        sendText(text)
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

    fun resolveApproval(allow: Boolean) {
        container.approval.resolve(allow)
    }

    private fun sendText(text: String, appendUser: Boolean = true) {
        val conversation = _state.value.current ?: return
        _state.update { it.copy(input = "", busy = true, error = null, options = emptyList()) }
        container.busy.value = true
        container.cancelRequested.value = false
        startRunService()
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            if (appendUser) {
                container.conversations.append(
                    conversation.id,
                    ChatMessage(
                        id = "m-$now-${UUID.randomUUID().toString().take(6)}",
                        role = "user",
                        text = text,
                        timestamp = now,
                    ),
                )
            }
            val history = conversation.messages.map { ModelMessage(it.role, it.text) }
            val memory = runCatching { container.memory.promptText() }.getOrDefault("")
            val skills = runCatching { container.skills.promptText() }.getOrDefault("")
            val bridged = runCatching { container.bridgedDevice() }.getOrNull()
            val current = container.settings.settings.first()
            val device = bridged
                ?: if (current.accessibilityAllowed) {
                    container.device
                } else {
                    com.hopa.capabilities.device.UnavailableDevicePort()
                }
            val loop = container.loopFor(device)
            val result = try {
                withTimeoutOrNull(120_000) {
                    loop.run(
                        runId = "run-$now",
                        traceId = UUID.randomUUID().toString(),
                        context = TurnContext(
                            goal = text,
                            history = history,
                            memory = memory,
                            skills = skills,
                        ),
                        isCancelled = { container.cancelRequested.value },
                    )
                }
            } finally {
                stopRunService()
            }
            container.conversations.append(
                conversation.id,
                ChatMessage(
                    id = "m-${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(6)}",
                    role = "assistant",
                    text = result?.answer ?: "I stopped after two minutes.",
                    timestamp = System.currentTimeMillis(),
                ),
            )
            val all = container.conversations.all()
            container.busy.value = false
            _state.update {
                it.copy(
                    current = all.firstOrNull { item -> item.id == conversation.id },
                    conversations = all,
                    busy = false,
                    error = result?.error?.message,
                    options = result?.options.orEmpty(),
                )
            }
        }.invokeOnCompletion { container.busy.value = false }
    }

    private fun startRunService() {
        val intent = Intent(container.context, com.hopa.app.service.RunService::class.java)
        runCatching {
            ContextCompat.startForegroundService(container.context, intent)
        }
    }

    private fun stopRunService() {
        runCatching {
            container.context.stopService(
                Intent(container.context, com.hopa.app.service.RunService::class.java),
            )
        }
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
