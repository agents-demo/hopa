package com.hopa.decision.graph

import kotlinx.serialization.json.Json

/**
 * Reads `graphs.v1.json` from the module resources.
 *
 * A missing or broken document is an empty list, not a crash: the app then uses
 * the model exactly as before. That is the only acceptable failure mode for a
 * hand-written optimisation.
 */
object GraphCatalog {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = false
    }

    /** One line per app for the Act page: what the graphs can finish. */
    fun summary(graphs: List<AppGraph> = load()): List<String> = graphs.map { graph ->
        val actions = graph.edges.filter { it.done }.mapNotNull { edge ->
            when {
                edge.to != null -> NODE_TITLES[edge.to] ?: edge.to.replace('-', ' ')
                edge.action.kind == "launch" -> "open"
                else -> null
            }
        }.distinct()
        if (actions.isEmpty()) graph.name else "${graph.name}: ${actions.joinToString(", ")}"
    }

    private val NODE_TITLES = mapOf(
        "wifi" to "Wi-Fi",
        "bluetooth" to "Bluetooth",
        "alarms" to "Alarms",
        "timer" to "Timer",
    )

    fun load(): List<AppGraph> = load(RESOURCE)

    /** A client-specific catalogue, e.g. the Windows app graphs. */
    fun load(resource: String): List<AppGraph> {
        val text = runCatching {
            GraphCatalog::class.java.getResourceAsStream(resource)?.use { stream ->
                stream.readBytes().decodeToString()
            }
        }.getOrNull() ?: return emptyList()
        return runCatching {
            val document = json.decodeFromString<GraphDocument>(text)
            if (document.schemaVersion == SUPPORTED) document.graphs else emptyList()
        }.getOrDefault(emptyList())
    }

    private const val RESOURCE = "/graphs.v1.json"
    private const val SUPPORTED = 1
}
