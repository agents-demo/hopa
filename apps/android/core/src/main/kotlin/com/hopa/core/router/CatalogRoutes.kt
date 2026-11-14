package com.hopa.core.router

import com.hopa.catalog.APP_CATALOG
import com.hopa.catalog.SITE_CATALOG

object CatalogRoutes {
    fun targets(): List<RouteTarget> {
        val apps = APP_CATALOG.map { app ->
            RouteTarget(
                name = app.id,
                display = app.display,
                kind = "app",
                bundle = app.bundle,
                aliases = app.aliases,
                purpose = app.purpose,
                actions = app.actions,
            )
        }
        val sites = SITE_CATALOG.map { site ->
            RouteTarget(
                name = site.id,
                display = site.display,
                kind = "site",
                domains = site.domains,
                aliases = site.aliases,
                purpose = site.purpose,
                actions = site.actions,
            )
        }
        return apps + sites
    }
}
