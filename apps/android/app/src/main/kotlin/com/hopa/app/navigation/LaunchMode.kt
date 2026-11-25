package com.hopa.app.navigation

import kotlinx.coroutines.withTimeoutOrNull

/**
 * How the app should open, decided once at launch from the configured gateway
 * and what identity is already stored.
 *
 * - [LocalOnly]: no gateway is configured and nothing is stored; the pairing
 *   entry is hidden.
 * - [LocalOnlyUnreachable]: a gateway is configured but the health probe failed
 *   or timed out; the app stays usable with a banner, and the pairing entry is
 *   still reachable.
 * - [SignIn]: the gateway answers and no identity is stored yet.
 * - [Paired]: the gateway answers and an identity is already stored.
 */
enum class LaunchMode {
    LocalOnly,
    LocalOnlyUnreachable,
    SignIn,
    Paired;

    companion object {
        /**
         * A pure decision: [configuredUrl] is `BuildConfig.BACKEND_URL` (null in
         * release), [storedUrl] and [storedDeviceId] are the stored identity, and
         * [reachable] is the health probe's answer (only consulted when something
         * is configured). This never throws, so an unreachable gateway can never
         * dead-end the launch.
         */
        fun decide(
            configuredUrl: String?,
            storedUrl: String,
            storedDeviceId: String,
            reachable: Boolean,
            skipped: Boolean = false,
        ): LaunchDecision {
            if (skipped) {
                // "Use this phone without an account" wins over a reachable
                // gateway; otherwise a configured URL traps the person here.
                return LaunchDecision(LocalOnly)
            }
            val url = configuredUrl?.trim().orEmpty().ifBlank { storedUrl.trim() }
            if (url.isBlank() && storedDeviceId.isBlank()) {
                return LaunchDecision(LocalOnly)
            }
            if (!reachable) {
                // A person who never signed in chose local mode; an account
                // notice would be noise. Someone who did sign in gets one plain
                // line that HOPA still works here.
                val note = if (storedDeviceId.isNotBlank()) {
                    "HOPA still works on this phone."
                } else {
                    null
                }
                return LaunchDecision(LocalOnlyUnreachable, banner = note)
            }
            return if (storedDeviceId.isNotBlank()) {
                LaunchDecision(Paired)
            } else {
                LaunchDecision(SignIn)
            }
        }
    }
}

/** What [LaunchMode.decide] chose, plus the banner and the pairing-entry rule. */
data class LaunchDecision(
    val mode: LaunchMode,
    val banner: String? = null,
) {
    /**
     * Whether the gateway pairing card should be shown. It is hidden only in
     * the no-gateway-at-all case; the unreachable case keeps it so the person
     * can retry.
     */
    val showGatewayPairing: Boolean get() = mode != LaunchMode.LocalOnly
}

/**
 * Probes the gateway only when something is configured, then delegates to the
 * pure [LaunchMode.decide]. A probe that throws or times out is treated as
 * unreachable, never as a crash.
 */
suspend fun resolveLaunch(
    configuredUrl: String?,
    storedUrl: String,
    storedDeviceId: String,
    health: suspend (String) -> Boolean,
    skipped: Boolean = false,
): LaunchDecision {
    val url = configuredUrl?.trim().orEmpty().ifBlank { storedUrl.trim() }
    if (url.isBlank() && storedDeviceId.isBlank()) {
        return LaunchMode.decide(configuredUrl, storedUrl, storedDeviceId, reachable = false, skipped = skipped)
    }
    val reachable = url.isNotBlank() && runCatching {
        // A cold gateway must not hold the launch screen forever: four seconds
        // is enough to know it is there, and an offline phone still starts local.
        withTimeoutOrNull(4_000) { health(url) } ?: false
    }.getOrDefault(false)
    return LaunchMode.decide(configuredUrl, storedUrl, storedDeviceId, reachable, skipped = skipped)
}
