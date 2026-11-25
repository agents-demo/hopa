package com.hopa.agent.decision.model

import com.hopa.agent.decision.StepPolicy
import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest

/** The provider the client configured: one request, one reply. */
class ModelStepPolicy(
    private val model: ModelPort,
    /** A local CPU model needs a short answer budget; null keeps the request. */
    private val maxTokens: Int? = null,
) : StepPolicy {
    override suspend fun next(request: ModelRequest): ModelReply = model.complete(
        if (maxTokens == null) request else request.copy(maxTokens = minOf(request.maxTokens, maxTokens)),
    )
}
