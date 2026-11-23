package com.hopa.sidecar

import com.hopa.sidecar.cli.CliOptions
import com.hopa.sidecar.cli.USAGE
import com.hopa.sidecar.cli.runHeadless
import com.hopa.sidecar.cli.runProtocol
import com.hopa.sidecar.protocol.Protocol
import kotlin.system.exitProcess

/**
 * The engine host's entry point: choose a mode, hand over, get out of the way.
 * Everything a mode needs lives in `cli/`.
 */
fun main(args: Array<String>) {
    val options = runCatching { CliOptions.parse(args) }.getOrElse { error ->
        System.err.println("hopa-sidecar: ${error.message}")
        System.err.println(USAGE)
        exitProcess(2)
    }
    if (options.help) {
        println(USAGE)
        return
    }
    if (options.version) {
        println("hopa-sidecar protocol v${Protocol.VERSION}")
        return
    }
    if (options.turn != null) {
        exitProcess(runHeadless(options))
    }
    runProtocol(options)
}
