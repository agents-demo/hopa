package com.hopa.capabilities.llm

class ProviderStateResolver {
    fun resolve(provider: String, endpoint: String, apiKey: String): ProviderState = when {
        provider == "stub" -> ProviderState.DEMO
        endpoint.startsWith("http://") -> ProviderState.LAN
        apiKey.isBlank() -> ProviderState.NO_MODEL
        else -> ProviderState.CLOUD
    }
}
