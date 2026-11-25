package com.hopa.data.store

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.hopa.stores.AppSettings
import com.hopa.stores.DEFAULT_BACKEND_URL
import com.hopa.stores.SecretStore
import com.hopa.stores.SettingsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "hopa_settings")

class DataStoreSettingsRepository(
    private val context: Context,
    private val secrets: SecretStore,
) : SettingsRepository {
    override val settings: Flow<AppSettings> =
        context.settingsDataStore.data.map(DataStoreSettingsRepository::settingsFrom)

    override suspend fun update(transform: (AppSettings) -> AppSettings) {
        val next = transform(settings.first())
        context.settingsDataStore.edit { prefs ->
            prefs[PROVIDER] = next.provider
            prefs[ENDPOINT] = next.endpoint
            prefs[MODEL] = next.model
            prefs[ACTIVE_MODEL_ID] = next.activeModelId
            prefs[PROFILE] = next.profile
            prefs[NOTIFY] = next.notifyAnswers
            prefs[SELECTED] = next.selectedConversation
            prefs[BRIDGE_URL] = next.bridgeUrl
            prefs[USE_BRIDGE] = next.useBridge
            prefs[ACCESSIBILITY_ALLOWED] = next.accessibilityAllowed
            prefs[TONE] = next.tone
            prefs[CHATTINESS] = next.chattiness
            prefs[SCREEN_PATH] = next.screenPath
            prefs[PLAN_FIRST] = next.planFirst
            prefs[REPLAY_SKILLS] = next.replaySkills
            prefs[INSTANT_COMMANDS] = next.instantCommands
            prefs[STEP_SOURCE] = next.stepSource
            prefs[TREE_RANKER] = next.treeRanker
            prefs[CLOUD_FALLBACK] = next.cloudFallback
            prefs[VISION] = next.vision
            prefs[MASCOT_FRAMED] = next.mascotFramed
            prefs[TRUSTED_APPS] = next.trustedApps
            prefs[DECISION_MODE] = next.decisionMode
            prefs[SHADOW_DECISIONS] = next.shadowDecisions
            prefs[ACCEPTED_MODEL_LICENCES] = next.acceptedModelLicences
            prefs[BACKEND_URL] = next.backendUrl
            prefs[BACKEND_DEVICE_ID] = next.backendDeviceId
            prefs[BACKEND_HOUSEHOLD_ID] = next.backendHouseholdId
            prefs[ACCOUNT_SKIPPED] = next.accountSkipped
        }
    }

    override suspend fun modelKey(): String = secrets.get(MODEL_KEY)

    override suspend fun hasModelKey(): Boolean = secrets.present(MODEL_KEY)

    override suspend fun setModelKey(value: String) = secrets.set(MODEL_KEY, value)

    override suspend fun bridgeToken(): String = secrets.get(BRIDGE_TOKEN)

    override suspend fun setBridgeToken(value: String) = secrets.set(BRIDGE_TOKEN, value)

    override suspend fun bridgeRefresh(): String = secrets.get(BRIDGE_REFRESH)

    override suspend fun setBridgeRefresh(value: String) = secrets.set(BRIDGE_REFRESH, value)

    override suspend fun backendAccessToken(): String = secrets.get(BACKEND_ACCESS)

    override suspend fun setBackendAccessToken(value: String) {
        if (value.isBlank()) secrets.clear(BACKEND_ACCESS) else secrets.set(BACKEND_ACCESS, value)
    }

    override suspend fun backendRefreshToken(): String = secrets.get(BACKEND_REFRESH)

    override suspend fun setBackendRefreshToken(value: String) {
        if (value.isBlank()) secrets.clear(BACKEND_REFRESH) else secrets.set(BACKEND_REFRESH, value)
    }

    override suspend fun backendPrivateKey(): String = secrets.get(BACKEND_PRIVATE_KEY)

    override suspend fun setBackendPrivateKey(value: String) {
        if (value.isBlank()) secrets.clear(BACKEND_PRIVATE_KEY) else secrets.set(BACKEND_PRIVATE_KEY, value)
    }

    override suspend fun backendContentKey(): String = secrets.get(BACKEND_CONTENT_KEY)

    override suspend fun setBackendContentKey(value: String) {
        if (value.isBlank()) secrets.clear(BACKEND_CONTENT_KEY) else secrets.set(BACKEND_CONTENT_KEY, value)
    }

    override suspend fun approvalSigningKey(): String = secrets.get(APPROVAL_SIGNING_KEY)

    override suspend fun setApprovalSigningKey(value: String) {
        if (value.isBlank()) secrets.clear(APPROVAL_SIGNING_KEY) else secrets.set(APPROVAL_SIGNING_KEY, value)
    }

    override suspend fun clearBackend() {
        secrets.clear(BACKEND_ACCESS)
        secrets.clear(BACKEND_REFRESH)
        secrets.clear(BACKEND_PRIVATE_KEY)
        secrets.clear(BACKEND_CONTENT_KEY)
        // A phone paired again is a new device to the PC: it signs with a new key.
        secrets.clear(APPROVAL_SIGNING_KEY)
        update {
            it.copy(
                backendUrl = DEFAULT_BACKEND_URL,
                backendDeviceId = "",
                backendHouseholdId = "",
            )
        }
    }

    internal companion object {
        /**
         * The stored settings. A key that was never written falls back to the
         * value the app ships with; an empty string is a written value and wins.
         */
        fun settingsFrom(prefs: Preferences): AppSettings = AppSettings(
            provider = prefs[PROVIDER] ?: "stub",
            endpoint = prefs[ENDPOINT] ?: "https://api.deepseek.com/v1",
            model = prefs[MODEL] ?: "deepseek-v4-flash",
            activeModelId = prefs[ACTIVE_MODEL_ID] ?: "",
            profile = prefs[PROFILE] ?: "everyday",
            notifyAnswers = prefs[NOTIFY] ?: true,
            selectedConversation = prefs[SELECTED] ?: "",
            bridgeUrl = prefs[BRIDGE_URL] ?: "",
            useBridge = prefs[USE_BRIDGE] ?: true,
            accessibilityAllowed = prefs[ACCESSIBILITY_ALLOWED] ?: true,
            tone = prefs[TONE] ?: "friendly",
            chattiness = prefs[CHATTINESS] ?: "balanced",
            screenPath = prefs[SCREEN_PATH] ?: "auto",
            planFirst = prefs[PLAN_FIRST] ?: false,
            replaySkills = prefs[REPLAY_SKILLS] ?: true,
            instantCommands = prefs[INSTANT_COMMANDS] ?: true,
            stepSource = prefs[STEP_SOURCE] ?: if (prefs[KNOWN_GRAPHS] == false) "model" else "auto",
            treeRanker = prefs[TREE_RANKER] ?: false,
            cloudFallback = prefs[CLOUD_FALLBACK] ?: false,
            vision = prefs[VISION] ?: false,
            mascotFramed = prefs[MASCOT_FRAMED] ?: false,
            trustedApps = prefs[TRUSTED_APPS] ?: emptySet(),
            decisionMode = prefs[DECISION_MODE] ?: "off",
            shadowDecisions = prefs[SHADOW_DECISIONS] ?: false,
            acceptedModelLicences = prefs[ACCEPTED_MODEL_LICENCES] ?: emptySet(),
            backendUrl = prefs[BACKEND_URL] ?: DEFAULT_BACKEND_URL,
            backendDeviceId = prefs[BACKEND_DEVICE_ID] ?: "",
            backendHouseholdId = prefs[BACKEND_HOUSEHOLD_ID] ?: "",
            accountSkipped = prefs[ACCOUNT_SKIPPED] ?: false,
        )

        val PROVIDER = stringPreferencesKey("provider")
        val ENDPOINT = stringPreferencesKey("endpoint")
        val MODEL = stringPreferencesKey("model")
        val ACTIVE_MODEL_ID = stringPreferencesKey("active_model_id")
        val PROFILE = stringPreferencesKey("profile")
        val NOTIFY = booleanPreferencesKey("notify_answers")
        val SELECTED = stringPreferencesKey("selected_conversation")
        val BRIDGE_URL = stringPreferencesKey("bridge_url")
        val USE_BRIDGE = booleanPreferencesKey("use_bridge")
        val ACCESSIBILITY_ALLOWED = booleanPreferencesKey("accessibility_allowed")
        val TONE = stringPreferencesKey("tone")
        val CHATTINESS = stringPreferencesKey("chattiness")
        val SCREEN_PATH = stringPreferencesKey("screen_path")
        val PLAN_FIRST = booleanPreferencesKey("plan_first")
        val REPLAY_SKILLS = booleanPreferencesKey("replay_skills")
        val INSTANT_COMMANDS = booleanPreferencesKey("instant_commands")
        val KNOWN_GRAPHS = booleanPreferencesKey("known_graphs")
        val STEP_SOURCE = stringPreferencesKey("step_source")
        val TREE_RANKER = booleanPreferencesKey("tree_ranker")
        val CLOUD_FALLBACK = booleanPreferencesKey("cloud_fallback")
        val VISION = booleanPreferencesKey("vision")
        val MASCOT_FRAMED = booleanPreferencesKey("mascot_framed")
        val TRUSTED_APPS = stringSetPreferencesKey("trusted_apps")
        val DECISION_MODE = stringPreferencesKey("decision_mode")
        val SHADOW_DECISIONS = booleanPreferencesKey("shadow_decisions")
        val ACCEPTED_MODEL_LICENCES = stringSetPreferencesKey("accepted_model_licences")
        val BACKEND_URL = stringPreferencesKey("backend_url")
        val BACKEND_DEVICE_ID = stringPreferencesKey("backend_device_id")
        val BACKEND_HOUSEHOLD_ID = stringPreferencesKey("backend_household_id")
        val ACCOUNT_SKIPPED = booleanPreferencesKey("account_skipped")
        const val MODEL_KEY = "model_key"
        const val BRIDGE_TOKEN = "bridge_token"
        const val BRIDGE_REFRESH = "bridge_refresh"
        const val BACKEND_ACCESS = "backend_access"
        const val BACKEND_REFRESH = "backend_refresh"
        const val BACKEND_PRIVATE_KEY = "backend_private_key"
        const val BACKEND_CONTENT_KEY = "backend_content_key"
        const val APPROVAL_SIGNING_KEY = "approval_signing_key"
    }
}
