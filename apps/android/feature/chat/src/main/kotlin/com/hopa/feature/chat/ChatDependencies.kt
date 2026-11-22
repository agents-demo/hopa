package com.hopa.feature.chat

import android.content.Context
import com.hopa.agent.turn.TurnOutcome
import com.hopa.agent.turn.TurnRequest
import com.hopa.capabilities.voice.VoiceRecorder
import com.hopa.contracts.approval.ApprovalRequest
import com.hopa.contracts.chat.Attachment
import com.hopa.contracts.task.TaskItem
import com.hopa.data.store.DbRunHistory
import com.hopa.observation.source.ScreenSourceDevice
import com.hopa.runtime.RunGate
import com.hopa.stores.AppSettings
import com.hopa.stores.ConversationStore
import com.hopa.stores.SettingsRepository
import com.hopa.stores.SkillStore
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** What the chat screen needs: one turn, the tasks beside it, and the prompt gate. */
interface ChatDependencies {
    val context: Context
    val conversations: ConversationStore
    val settings: SettingsRepository
    val selectedConversation: MutableStateFlow<String?>
    val pendingAttachment: MutableStateFlow<Attachment?>
    val pendingNotice: MutableStateFlow<String?>
    val pendingGoals: Channel<String>
    val runHistory: DbRunHistory
    val skills: SkillStore
    val runGate: RunGate
    val surfaces: suspend (AppSettings) -> ScreenSourceDevice
    val voice: VoiceRecorder

    val pendingApproval: StateFlow<ApprovalRequest?>
    val tasks: StateFlow<List<TaskItem>>

    /** Pieces of an on-device answer as they are produced; empty for cloud. */
    val localTokens: kotlinx.coroutines.flow.Flow<String>

    /** Where a graph would go before any screen is read, or null. */
    fun graphTarget(goal: String): com.hopa.decision.graph.GraphTarget?

    fun resolveApproval(allow: Boolean)

    fun canStartTask(): Boolean

    fun startTask(goal: String)

    fun dismissTask(id: String)

    suspend fun deleteAttachment(attachment: Attachment)

    fun planRequest(goal: String, runId: String, traceId: String): TurnRequest

    suspend fun request(
        goal: String,
        device: ScreenSourceDevice,
        settings: AppSettings,
        runId: String,
        traceId: String,
        history: List<com.hopa.contracts.model.ModelMessage> = emptyList(),
    ): TurnRequest

    suspend fun runTurn(
        request: TurnRequest,
        isCancelled: () -> Boolean = { false },
    ): TurnOutcome

    suspend fun speak(text: String): Boolean

    suspend fun transcribe(wav: ByteArray): String?

    fun useGate(trustedApps: Collection<String>, autonomous: Boolean = false)

    /** Use these decision settings for the steps of the turns that start now. */
    fun useDecisions(mode: String, shadow: Boolean)

    /** Ask the running turn to stop and abort a native decode if one is running. */
    fun stopTurn()

    /** The model label for the receipt, including the installed file's name. */
    suspend fun onDeviceModelName(): String

    fun bringToFront()

    fun releaseSurfaces()

    fun isForeground(): Boolean

    fun postAnswer(text: String)

    fun startRunService()

    fun stopRunService()
}
