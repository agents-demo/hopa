package com.hopa.sidecar

/**
 * Aliases a person or a model uses for a Windows settings page, mapped to the URI
 * that opens it. Exact aliases only: a package name must never be rewritten by a
 * substring match.
 */
class WindowsIntents(
    private val table: Map<String, String> = DEFAULT,
) {
    fun resolve(target: String): String? {
        val value = target.trim()
        if (value.isEmpty()) {
            return null
        }

        val lower = value.lowercase()
        if (lower.startsWith("ms-settings:")) {
            return lower
        }

        if (lower.startsWith("http://") || lower.startsWith("https://")) {
            return value
        }

        // A dotted target is a package or bundle id, not an alias.
        if (value.contains('.')) {
            return null
        }

        return table[lower]
    }

    companion object {
        val DEFAULT: Map<String, String> = mapOf(
            "settings" to "ms-settings:",
            "wifi" to "ms-settings:network-wifi",
            "wi-fi" to "ms-settings:network-wifi",
            "wireless" to "ms-settings:network-wifi",
            "network" to "ms-settings:network",
            "ethernet" to "ms-settings:network-ethernet",
            "vpn" to "ms-settings:network-vpn",
            "proxy" to "ms-settings:network-proxy",
            "bluetooth" to "ms-settings:bluetooth",
            "display" to "ms-settings:display",
            "sound" to "ms-settings:sound",
            "notifications" to "ms-settings:notifications",
            "apps" to "ms-settings:appsfeatures",
            "default apps" to "ms-settings:defaultapps",
            "storage" to "ms-settings:storagesense",
            "privacy" to "ms-settings:privacy",
            "windows update" to "ms-settings:windowsupdate",
            "update" to "ms-settings:windowsupdate",
            "about" to "ms-settings:about",
            "date" to "ms-settings:dateandtime",
            "time" to "ms-settings:dateandtime",
            "language" to "ms-settings:regionlanguage",
            "power" to "ms-settings:powersleep",
            "mouse" to "ms-settings:mousetouchpad",
            "keyboard" to "ms-settings:keyboard",
            "personalization" to "ms-settings:personalization",
            "accessibility" to "ms-settings:easeofaccess",
        )
    }
}
