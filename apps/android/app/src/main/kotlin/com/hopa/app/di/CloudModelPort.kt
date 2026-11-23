package com.hopa.app.di

import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest
import com.hopa.inference.client.ModelFactory
import com.hopa.stores.SettingsRepository
import java.io.IOException
import kotlinx.coroutines.flow.first

/**
 * The API model, whatever the person picked for the turn.
 *
 * This port exists for one rung of the chain: a turn may end on the cloud model
 * when the on-device one is not sure and the person allowed it. It never falls
 * back to a demo answer - without a key there is no cloud rung at all.
 */
class CloudModelPort(
    private val settings: SettingsRepository,
    private val factory: ModelFactory,
) : ModelPort {
    override suspend fun complete(request: ModelRequest): ModelReply {
        val current = settings.settings.first()
        val key = settings.modelKey()
        if (key.isBlank()) {
            throw IOException("no model key configured")
        }
        return factory
            .create(provider = "api", endpoint = current.endpoint, apiKey = key, modelName = current.model)
            .complete(request)
    }
}
