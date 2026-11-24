package com.hopa.contracts.model

data class ModelRequest(
    val messages: List<ModelMessage>,
    val maxTokens: Int = 2048,
    val reasoningEffort: String = "",
    /** Base64 frames of the screen; the client detects PNG or JPEG from the signature. */
    val images: List<String> = emptyList(),
)
