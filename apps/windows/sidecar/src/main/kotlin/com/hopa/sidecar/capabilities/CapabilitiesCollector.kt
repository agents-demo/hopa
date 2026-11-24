package com.hopa.sidecar.capabilities

import com.hopa.agent.recipe.RecipeStore
import com.hopa.catalog.routing.CatalogRoutes
import com.hopa.sidecar.store.ChatStore
import com.hopa.sidecar.store.MemoryFileStore
import com.hopa.sidecar.store.RecordStore
import com.hopa.sidecar.store.SkillFileStore
import com.hopa.sidecar.turn.RuntimeConfig
import com.hopa.sidecar.turn.SidecarCatalog
import com.hopa.stores.Profiles

/** What this PC can actually do, for the capabilities screen. */
data class CapabilitiesSummary(
    val platform: String,
    val profile: String,
    val modelProvider: String,
    val modelName: String,
    val modelReady: Boolean,
    val bridge: Boolean,
    val gatewayPaired: Boolean,
    val phoneOnline: Boolean,
    val memory: Int,
    val skills: Int,
    val recipes: Int,
    val runs: Int,
    val windowsApps: Int,
)

/** Reads the live state once; no capability is inferred from a setting alone. */
internal class CapabilitiesCollector(
    private val config: RuntimeConfig,
    private val memory: MemoryFileStore,
    private val skills: SkillFileStore,
    private val recipes: RecipeStore,
    private val records: RecordStore,
) {
    suspend fun collect(): CapabilitiesSummary {
        val apps = CatalogRoutes
            .targets(platform = "windows", knowledge = SidecarCatalog.value)
            .count { it.kind == "app" && it.bundle.isNotEmpty() }

        return CapabilitiesSummary(
            platform = "windows",
            profile = config.profile,
            modelProvider = config.modelProvider,
            modelName = config.modelName,
            modelReady = config.hasModel,
            bridge = config.hasBridge,
            gatewayPaired = config.gatewayPaired,
            phoneOnline = config.gatewayPhoneOnline,
            memory = memory.all().size,
            skills = skills.all().size,
            recipes = recipes.all().size,
            runs = records.count(),
            windowsApps = apps,
        )
    }
}
