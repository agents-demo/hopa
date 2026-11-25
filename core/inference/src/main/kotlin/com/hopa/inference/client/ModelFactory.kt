package com.hopa.inference.client

import com.hopa.contracts.model.ModelPort
import com.hopa.inference.choice.ProviderChoice
import com.hopa.inference.choice.ProviderChoiceRules
import com.hopa.inference.local.LocalEndpoint
import com.hopa.inference.local.LocalEngine

class ModelFactory(
    private val rules: ProviderChoiceRules = ProviderChoiceRules(),
    private val localEngine: LocalEngine? = null,
) {
    fun create(provider: String, endpoint: String, apiKey: String, modelName: String): ModelPort =
        when (rules.choose(provider, endpoint, apiKey)) {
            ProviderChoice.DEMO -> DemoModelClient()
            ProviderChoice.ON_DEVICE -> LocalModel(
                localEngine ?: loopbackEngine(endpoint, modelName),
            )
            ProviderChoice.CLOUD, ProviderChoice.LAN -> OpenAiClient(
                endpoint = endpoint,
                apiKey = apiKey,
                modelName = modelName,
                // A loopback CPU model can take minutes for a long screen.
                readTimeoutSeconds = if (modelName.equals("local", ignoreCase = true)) 600 else 60,
            )
        }

    /**
     * Windows keeps llama.cpp in its own process, so the sidecar finds it on
     * loopback. Any other address is refused here: an "on-device" answer must
     * never travel to a server that is not this machine.
     */
    private fun loopbackEngine(endpoint: String, modelName: String): LocalEngine? = endpoint
        .takeIf(LocalEndpoint::isLoopback)
        ?.let { HttpLocalEngine(it, modelName) }
}
