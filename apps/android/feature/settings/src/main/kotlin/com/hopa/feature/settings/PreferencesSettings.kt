package com.hopa.feature.settings

import com.hopa.stores.SettingsRepository

/**
 * The words HOPA uses and the small switches around them: tone, length, mascot,
 * alerts, replays, planning, trust. Every write goes through the repository, so
 * the screen ViewModel only has to re-read what it shows.
 */
internal class PreferencesSettings(
    private val settings: SettingsRepository,
) {
    suspend fun setTone(value: String) {
        settings.update { it.copy(tone = value) }
    }

    suspend fun setChattiness(value: String) {
        settings.update { it.copy(chattiness = value) }
    }

    suspend fun setMascotFramed(value: Boolean) {
        settings.update { it.copy(mascotFramed = value) }
    }

    suspend fun setNotifications(value: Boolean) {
        settings.update { it.copy(notifyAnswers = value) }
    }

    suspend fun setReplaySkills(value: Boolean) {
        settings.update { it.copy(replaySkills = value) }
    }

    suspend fun setPlanFirst(value: Boolean) {
        settings.update { it.copy(planFirst = value) }
    }

    suspend fun setDecisionMode(value: String) {
        settings.update { it.copy(decisionMode = value) }
    }

    suspend fun setShadowDecisions(value: Boolean) {
        settings.update { it.copy(shadowDecisions = value) }
    }

    suspend fun setInstantCommands(value: Boolean) {
        settings.update { it.copy(instantCommands = value) }
    }

    suspend fun setStepSource(value: String) {
        settings.update { it.copy(stepSource = value) }
    }

    suspend fun setCloudFallback(value: Boolean) {
        settings.update { it.copy(cloudFallback = value) }
    }

    suspend fun setTrusted(packageName: String, trusted: Boolean) {
        if (packageName.isBlank()) {
            return
        }
        settings.update { current ->
            current.copy(
                trustedApps = if (trusted) {
                    current.trustedApps + packageName
                } else {
                    current.trustedApps - packageName
                },
            )
        }
    }
}
