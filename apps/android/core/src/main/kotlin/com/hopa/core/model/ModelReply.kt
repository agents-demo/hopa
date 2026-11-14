package com.hopa.core.model

data class ModelReply(
    val text: String,
    val usage: ModelUsage = ModelUsage(),
)
