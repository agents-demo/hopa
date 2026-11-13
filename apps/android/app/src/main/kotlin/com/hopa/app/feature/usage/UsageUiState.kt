package com.hopa.app.feature.usage

data class UsageUiState(
    val total: Int = 0,
    val executed: Int = 0,
    val failed: Int = 0,
    val payments: Int = 0,
    val lastSevenDays: Int = 0,
    val topActions: List<Pair<String, Int>> = emptyList(),
)
