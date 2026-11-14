package com.hopa.sidecar

import com.hopa.sidecar.Protocol.asObject
import com.hopa.sidecar.Protocol.text
import com.hopa.sidecar.Protocol.type

fun main() {
    val io = Stdio()
    val device = HostDevice(io)
    val engine = Engine(io, device)
    io.send(Protocol.ready())
    io.log("ready (protocol v${Protocol.VERSION})")
    while (true) {
        val line = readLine() ?: break
        if (line.isBlank()) continue
        val message = line.asObject() ?: continue
        when (message.type()) {
            "hello" -> io.send(Protocol.ready())
            "turn.start" -> engine.startTurn(message.text("id"), message.text("goal"))
            "device.result" -> device.resolve(message.text("id"), message.text("ok").toBoolean())
            "shutdown" -> return
            else -> io.log("unknown message: ${message.type()}")
        }
    }
}
