package com.hopa.sidecar

import kotlinx.serialization.json.JsonObject

/** One line out, one line in; stdout is the protocol channel, stderr is logs. */
class Stdio {
    fun send(message: JsonObject) {
        println(message.toString())
        System.out.flush()
    }

    fun log(text: String) {
        System.err.println("[sidecar] $text")
        System.err.flush()
    }
}
