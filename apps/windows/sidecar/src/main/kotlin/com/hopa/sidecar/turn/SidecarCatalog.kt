package com.hopa.sidecar.turn

import com.hopa.catalog.data.ApprovalPolicyData
import com.hopa.catalog.store.CatalogCodec
import com.hopa.catalog.store.CatalogSnapshot

/** The bootstrap bundle packaged with the sidecar; the same document as the app. */
object SidecarCatalog {
    val value: CatalogSnapshot by lazy {
        val text = checkNotNull(SidecarCatalog::class.java.getResourceAsStream("/knowledge.v1.json")) {
            "knowledge.v1.json is missing from the sidecar resources"
        }.bufferedReader(Charsets.UTF_8).use { it.readText() }
        CatalogCodec.decode(text).toCatalogSnapshot(ApprovalPolicyData)
    }
}
