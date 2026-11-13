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
        }
    }

    override suspend fun modelKey(): String = secrets.get(MODEL_KEY)

    override suspend fun setModelKey(value: String) = secrets.set(MODEL_KEY, value)

    private companion object {
        val PROVIDER = stringPreferencesKey("provider")
        val ENDPOINT = stringPreferencesKey("endpoint")
        val MODEL = stringPreferencesKey("model")
        val PROFILE = stringPreferencesKey("profile")
        val NOTIFY = booleanPreferencesKey("notify_answers")
        val WEB = booleanPreferencesKey("web_enabled")
        const val MODEL_KEY = "model_key"
    }
}
