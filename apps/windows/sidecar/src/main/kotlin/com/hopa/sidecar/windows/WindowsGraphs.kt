package com.hopa.sidecar.windows

import com.hopa.decision.graph.AppGraph
import com.hopa.decision.graph.GraphCatalog

/**
 * The Windows graph catalogue. It lives beside the sidecar, not in the shared
 * Android resource, so the two clients never shadow each other's `/graphs.v1.json`.
 * A missing or broken file is an empty list; the model path then runs unchanged.
 */
object WindowsGraphs {
    private const val RESOURCE = "/windows-graphs.v1.json"

    fun load(): List<AppGraph> = GraphCatalog.load(RESOURCE)
}
