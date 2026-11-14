package com.hopa.core.loop

import com.hopa.core.model.ModelMessage

data class TurnContext(
    val goal: String,
    val history: List<ModelMessage> = emptyList(),
    val memory: String = "",
    val skills: String = "",
)
