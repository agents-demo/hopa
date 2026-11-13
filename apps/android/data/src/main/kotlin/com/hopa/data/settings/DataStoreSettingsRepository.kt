package com.hopa.data.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.hopa.data.secrets.SecretStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "hopa_settings")

class DataStoreSettingsRepository(
    private val context: Context,
    private val secrets: SecretStore,
) : SettingsRepository {
    override val settings: Flow<AppSettings> = context.settingsDataStore.data.map { prefs ->
        AppSettings(
            provider = prefs[PROVIDER] ?: "stub",
            endpoint = prefs[ENDPOINT] ?: "https://api.deepseek.com/v1",
            model = prefs[MODEL] ?: "deepseek-v4-flash",
            profile = prefs[PROFILE] ?: "everyday",
            notifyAnswers = prefs[NOTIFY] ?: true,
            webEnabled = prefs[WEB] ?: true,
            selectedConversation = prefs[SELECTED] ?: "",
            bridgeUrl = prefs[BRIDGE_URL] ?: "",
            useBridge = prefs[USE_BRIDGE] ?: true,
            accessibilityAllowed = prefs[ACCESSIBILITY_ALLOWED] ?: true,
        )
    }

    override suspend fun update(transform: (AppSettings) -> AppSettings) {
        val next = transform(settings.first())
        context.settingsDataStore.edit { prefs ->
            prefs[PROVIDER] = next.provider
            prefs[ENDPOINT] = next.endpoint
            prefs[MODEL] = next.model
            prefs[PROFILE] = next.profile
            prefs[NOTIFY] = next.notifyAnswers
            prefs[WEB] = next.webEnabled
            prefs[SELECTED] = next.selectedConversation
            prefs[BRIDGE_URL] = next.bridgeUrl
            prefs[USE_BRIDGE] = next.useBridge
            prefs[ACCESSIBILITY_ALLOWED] = next.accessibilityAllowed
        }
    }

    override suspend fun modelKey(): String = secrets.get(MODEL_KEY)

    override suspend fun setModelKey(value: String) = secrets.set(MODEL_KEY, value)

    override suspend fun bridgeToken(): String = secrets.get(BRIDGE_TOKEN)

    override suspend fun setBridgeToken(value: String) = secrets.set(BRIDGE_TOKEN, value)

    override suspend fun bridgeRefresh(): String = secrets.get(BRIDGE_REFRESH)

    override suspend fun setBridgeRefresh(value: String) = secrets.set(BRIDGE_REFRESH, value)

    private companion object {
        val PROVIDER = stringPreferencesKey("provider")
        val ENDPOINT = stringPreferencesKey("endpoint")
        val MODEL = stringPreferencesKey("model")
        val PROFILE = stringPreferencesKey("profile")
        val NOTIFY = booleanPreferencesKey("notify_answers")
        val WEB = booleanPreferencesKey("web_enabled")
        val SELECTED = stringPreferencesKey("selected_conversation")
        val BRIDGE_URL = stringPreferencesKey("bridge_url")
        val USE_BRIDGE = booleanPreferencesKey("use_bridge")
        val ACCESSIBILITY_ALLOWED = booleanPreferencesKey("accessibility_allowed")
        const val MODEL_KEY = "model_key"
        const val BRIDGE_TOKEN = "bridge_token"
        const val BRIDGE_REFRESH = "bridge_refresh"
    }
}
