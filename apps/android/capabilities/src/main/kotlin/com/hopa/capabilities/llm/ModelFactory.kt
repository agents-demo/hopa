package com.hopa.capabilities.llm

import com.hopa.core.model.ModelPort

class ModelFactory {
    fun create(
        provider: String,
        endpoint: String,
        apiKey: String,
        modelName: String,
    ): ModelPort = when (provider) {
        "stub" -> StubModelClient()
        else -> OpenAiClient(
            endpoint = endpoint,
            apiKey = apiKey,
            modelName = modelName,
        )
    }
}
