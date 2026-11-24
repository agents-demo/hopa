package com.hopa.sidecar.protocol.handler

import com.hopa.sidecar.browser.HostBrowser
import com.hopa.sidecar.protocol.Protocol.text
import kotlinx.serialization.json.JsonObject

/** The host answers a browser request (`browser.result`) by id. */
internal class BrowserHandler(
    private val browser: HostBrowser,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (type != "browser.result") {
            return false
        }

        browser.resolve(message.text("id"), message)
        return true
    }
}
