package com.hopa.sidecar

import com.hopa.core.gate.ActionExecutor
import com.hopa.core.gate.ApprovalPolicy
import com.hopa.core.loop.AgentLoop
import com.hopa.core.loop.TurnContext
import com.hopa.core.model.ModelMessage
import com.hopa.core.records.InMemoryRunRecorder
import com.hopa.core.records.RunRecordFactory
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** One turn at a time for W1; the loop and the gate are the real ones. */
class Engine(
    private val io: Stdio,
    private val device: HostDevice,
    private val store: ChatStore,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val clock = SystemClock()

    fun startTurn(id: String, goal: String, conversationId: String?) {
        scope.launch {
            val conversation = conversationId?.let { store.get(it) } ?: store.create()
            val history = conversation.messages.map { ModelMessage(it.role, it.text) }
            store.append(conversation.id, "user", goal)
            io.log("turn $id in ${conversation.id}: $goal")

            val recorder = InMemoryRunRecorder()
            val executor = ActionExecutor(
                device = device,
                browser = null,
                system = null,
                sandbox = null,
                policy = ApprovalPolicy(),
                approval = SpikeApproval(),
                recorder = recorder,
                factory = RunRecordFactory(clock),
                clock = clock,
            )
            val loop = AgentLoop(
                model = SpikeModel(),
                device = device,
                executor = executor,
                recorder = recorder,
                clock = clock,
                webAvailable = false,
            )
            val answer = runCatching {
                loop.run(
                    runId = "run-$id",
                    traceId = UUID.randomUUID().toString(),
                    context = TurnContext(goal = goal, history = history),
                ).answer
            }.getOrElse { error ->
                "The sidecar failed: ${error.message}"
            }

            store.append(conversation.id, "assistant", answer)
            val updated = store.get(conversation.id)
            io.send(Protocol.turnEnd(id, conversation.id, updated?.title ?: "New chat", answer))
        }
    }
}
