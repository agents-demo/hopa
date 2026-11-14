package com.hopa.core.model

data class ModelRequest(
    val messages: List<ModelMessage>,
    val maxTokens: Int = 2048,
    val reasoningEffort: String = "low",
)
