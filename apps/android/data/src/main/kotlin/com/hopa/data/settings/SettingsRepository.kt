package com.hopa.data.settings

import kotlinx.coroutines.flow.Flow

interface SettingsRepository {
    val settings: Flow<AppSettings>

    suspend fun update(transform: (AppSettings) -> AppSettings)

    suspend fun modelKey(): String

    suspend fun setModelKey(value: String)

    suspend fun bridgeToken(): String

    suspend fun setBridgeToken(value: String)

    suspend fun bridgeRefresh(): String

    suspend fun setBridgeRefresh(value: String)
}
