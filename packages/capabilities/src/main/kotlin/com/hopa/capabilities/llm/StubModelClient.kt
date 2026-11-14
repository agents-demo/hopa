package com.hopa.capabilities.llm

import com.hopa.core.model.ModelPort
import com.hopa.core.model.ModelReply
import com.hopa.core.model.ModelRequest
import kotlinx.coroutines.delay

class StubModelClient : ModelPort {
    override suspend fun complete(request: ModelRequest): ModelReply {
        delay(250)
        val last = request.messages
            .lastOrNull { it.role == "user" && !it.content.startsWith("SCREEN:") }
            ?.content
            .orEmpty()
        val screen = request.messages.lastOrNull { it.content.startsWith("SCREEN:") }?.content
        val seen = screen?.lines()?.drop(1)?.filter { it.isNotBlank() }?.take(2)?.joinToString(" ")
        val answer = when {
            last.contains("bridge demo", ignoreCase = true) -> {
                if (seen?.contains("Settings") == true) {
                    "Bridge demo: Settings is open. I can see: $seen"
                } else {
                    """{"schemaVersion":"1","kind":"ui.launch","app":"com.android.settings","timeoutMs":8000}"""
                }
            }

            last.contains("look", ignoreCase = true) && !seen.isNullOrBlank() ->
                "I can see: $seen"
            last.contains("2 plus 2", ignoreCase = true) -> "2 plus 2 is 4."
            last.contains("hello", ignoreCase = true) -> "Hello. This is the local demo model. " +
                "Add a provider key in Settings to use a real model."
            last.contains("share", ignoreCase = true) ->
                """{"schemaVersion":"1","kind":"system.share","text":"Hello from HOPA","timeoutMs":3000}"""

            last.isBlank() -> "Ask me something."
            else -> "Demo model: I received \"${last.take(120)}\". " +
                "Add a provider key in Settings to get real answers and run actions."
        }
        return ModelReply(answer)
    }
}
