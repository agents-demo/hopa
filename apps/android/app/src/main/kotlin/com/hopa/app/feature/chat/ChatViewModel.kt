package com.hopa.app.feature.chat

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

    fun resolveApproval(allow: Boolean) {
        container.approval.resolve(allow)
    }

    private fun sendText(text: String) {
        val conversation = _state.value.current ?: return
        _state.update { it.copy(input = "", busy = true, error = null, options = emptyList()) }
        container.busy.value = true
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            container.conversations.append(
                conversation.id,
                ChatMessage(
                    id = "m-$now-${UUID.randomUUID().toString().take(6)}",
                    role = "user",
                    text = text,
                    timestamp = now,
                ),
            )
            val history = conversation.messages.map { ModelMessage(it.role, it.text) }
            val bridged = runCatching { container.bridgedDevice() }.getOrNull()
            val current = container.settings.settings.first()
            val device = bridged
                ?: if (current.accessibilityAllowed) {
                    container.device
                } else {
                    com.hopa.capabilities.device.UnavailableDevicePort()
                }
            val loop = container.loopFor(device)
            val result = loop.run(
                runId = "run-$now",
                traceId = UUID.randomUUID().toString(),
                context = TurnContext(goal = text, history = history),
            )
            container.conversations.append(
                conversation.id,
                ChatMessage(
                    id = "m-${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(6)}",
                    role = "assistant",
                    text = result.answer,
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
                    error = result.error?.message,
                    options = result.options,
                )
            }
        }.invokeOnCompletion { container.busy.value = false }
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
