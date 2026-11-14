package com.hopa.core.prompt

import com.hopa.catalog.APP_CATALOG
import com.hopa.catalog.SITE_CATALOG

object AppCatalogBlock {
    fun text(): String {
        val lines = mutableListOf("KNOWN APPS AND SITES:")
        for (app in APP_CATALOG) {
            val purpose = app.purpose.takeIf { it.isNotEmpty() }?.let { " - $it" } ?: ""
            lines += "${app.display}$purpose"
        }
        for (site in SITE_CATALOG) {
            val domain = site.domains.firstOrNull() ?: continue
            val purpose = site.purpose.takeIf { it.isNotEmpty() }?.let { " - $it" } ?: ""
            lines += "${site.display} (site: $domain)$purpose"
        }
        lines += ""
        lines += "Open an app by its installed package name with ui.launch. " +
            "If the package is not known, open the app through the launcher and read the screen. " +
            "Open a site with web.navigate when the browser is available."
        return lines.joinToString("\n")
    }
}
