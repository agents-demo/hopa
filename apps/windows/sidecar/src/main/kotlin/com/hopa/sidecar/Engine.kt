package com.hopa.sidecar

import com.hopa.core.gate.ActionExecutor
import com.hopa.core.gate.ApprovalPolicy
import com.hopa.core.loop.AgentLoop
import com.hopa.core.loop.TurnContext
import com.hopa.core.records.InMemoryRunRecorder
import com.hopa.core.records.RunRecordFactory
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** One turn at a time for W0; the loop and the gate are the real ones. */
class Engine(
    private val io: Stdio,
    private val device: HostDevice,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val clock = SystemClock()

    fun startTurn(id: String, goal: String) {
        scope.launch {
            io.log("turn $id: $goal")
            val recorder = InMemoryRunRecorder()
            val policy = ApprovalPolicy()
            val executor = ActionExecutor(
                device = device,
                browser = null,
                system = null,
                sandbox = null,
                policy = policy,
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
            val result = runCatching {
                loop.run(
                    runId = "run-$id",
                    traceId = UUID.randomUUID().toString(),
                    context = TurnContext(goal = goal),
                )
            }.getOrElse { error ->
                io.send(Protocol.turnEnd(id, "The sidecar failed: ${error.message}"))
                return@launch
            }
            io.send(Protocol.turnEnd(id, result.answer))
        }
    }
}
