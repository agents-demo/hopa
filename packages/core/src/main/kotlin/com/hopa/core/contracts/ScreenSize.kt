package com.hopa.core.contracts

import kotlinx.serialization.Serializable

@Serializable
data class ScreenSize(
    val width: Int,
    val height: Int,
)
