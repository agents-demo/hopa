package com.hopa.sidecar.cli

import com.hopa.sidecar.approval.DenyAllApproval
import com.hopa.sidecar.turn.Engine
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.device.HeadlessDevice
import com.hopa.sidecar.protocol.Stdio
import com.hopa.sidecar.turn.RuntimeConfig
import kotlinx.coroutines.runBlocking

/** One turn through the real loop, the real gate and the fail-closed stubs. */
internal fun runHeadless(options: CliOptions): Int {
    val io = Stdio()
    val dataDir = options.dataDir ?: defaultDataDir()
    val store = ChatStore(dataDir.resolve("conversations.json"))
    val records = RecordStore(dataDir.resolve("records.json"))
    val approvals = DenyAllApproval()
    val engine = Engine(
        io = io,
        hostDevice = HeadlessDevice(),
        approval = approvals,
        store = store,
        recordStore = records,
        config = RuntimeConfig(),
        forceStub = true,
        deviceAttached = false,
    )
    val outcome = runBlocking {
        engine.runTurn(
            id = "cli-1",
            goal = options.turn.orEmpty(),
            conversationId = options.conversationId,
        )
    }
    println(Protocol.headlessTurn("cli-1", outcome).toString())
    io.log(
        "headless turn done: records=${outcome.records.size} " +
            "approvals=${approvals.requests} chainOk=${outcome.chainOk}",
    )
    return 0
}
