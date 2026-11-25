package com.hopa.inference.client

import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest
import com.hopa.inference.local.LocalEngine

/**
 * The on-device model when the runtime lives in another process.
 *
 * Windows owns the llama.cpp server and keeps it on loopback; the sidecar
 * reaches it with the OpenAI-compatible client it already ships. The choice
 * stays `on-device` in the receipt, so a person can see that nothing outside
 * this machine answered.
 *
 * Grammar is not forwarded: llama.cpp's HTTP endpoint does not take the GBNF
 * string the Android JNI build receives, and the decision parser still checks
 * the shape of the reply.
 */
class HttpLocalEngine(
    endpoint: String,
    modelName: String = LOCAL_MODEL_NAME,
) : LocalEngine {
    private val client = OpenAiClient(
        endpoint = endpoint,
        apiKey = LOCAL_API_KEY,
        modelName = modelName,
        // A CPU model needs minutes for a full screen.
        readTimeoutSeconds = LOCAL_READ_TIMEOUT_SECONDS,
    )

    override suspend fun complete(request: ModelRequest, grammar: String): ModelReply = client.complete(request)

    companion object {
        /** The server is started with this model name; llama.cpp ignores it. */
        const val LOCAL_MODEL_NAME: String = "local"
        private const val LOCAL_API_KEY: String = "local"
        private const val LOCAL_READ_TIMEOUT_SECONDS: Long = 600
    }
}
