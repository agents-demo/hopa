package com.hopa.capabilities.system

import android.content.Context
import android.content.Intent
import com.hopa.core.ports.InstalledApp
import com.hopa.core.ports.PackageCatalog

class AndroidPackageCatalog(
    private val context: Context,
) : PackageCatalog {
    override suspend fun installed(): List<InstalledApp> {
        val manager = context.packageManager
        return manager.getInstalledApplications(0)
            .asSequence()
            .filter { it.packageName != context.packageName }
            .map {
                InstalledApp(
                    packageName = it.packageName,
                    label = manager.getApplicationLabel(it).toString(),
                )
            }
            .sortedBy { it.label.lowercase() }
            .toList()
    }

    override suspend fun launch(packageName: String) {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: throw IllegalArgumentException("no launch intent for $packageName")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
