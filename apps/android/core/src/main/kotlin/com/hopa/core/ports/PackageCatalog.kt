package com.hopa.core.ports

interface PackageCatalog {
    suspend fun installed(): List<InstalledApp>

    suspend fun launch(packageName: String)
}
