package com.hopa.app.model

import com.hopa.capabilities.llm.ModelFactory
import com.hopa.core.model.ModelPort
import com.hopa.core.model.ModelReply
import com.hopa.core.model.ModelRequest
import com.hopa.data.settings.SettingsRepository
import java.io.IOException
import kotlinx.coroutines.flow.first

class SettingsModelPort(
    private val settings: SettingsRepository,
    private val factory: ModelFactory,
) : ModelPort {
    private var cachedKey: String = ""
    private var cached: ModelPort? = null

    override suspend fun complete(request: ModelRequest): ModelReply {
        val current = settings.settings.first()
        val key = settings.modelKey()
        if (current.provider != "stub" && key.isBlank()) {
            throw IOException("no model key configured")
        }
        val signature = "${current.provider}|${current.endpoint}|${current.model}|$key"
        val model = if (signature == cachedKey && cached != null) {
            cached!!
        } else {
            factory.create(current.provider, current.endpoint, key, current.model).also {
                cached = it
                cachedKey = signature
            }
        }
        return model.complete(request)
    }
}
