package com.hopa.feature.settings

import com.hopa.inference.local.InstalledModel
import com.hopa.inference.local.LocalModelQuota
import com.hopa.inference.local.ModelSpec

/** What the on-device section shows: the offer, the files, and the outcome. */
data class LocalModelUiState(
    val recommended: ModelSpec? = null,
    val installed: List<InstalledModel> = emptyList(),
    val installedSpecs: Map<String, ModelSpec> = emptyMap(),
    /** The catalogue id that answers on-device turns; empty before the first pick. */
    val activeId: String = "",
    val totalBytes: Long = 0,
    val ramGb: Int = 0,
    val quotaBytes: Long = LocalModelQuota.MAX_BYTES,
    val acceptedLicences: Set<String> = emptySet(),
    /** Installed ids whose catalogue hash no longer matches the file on disk. */
    val updates: Set<String> = emptySet(),
    /** Set when a download waits for the person to accept the licence. */
    val licenceFor: ModelSpec? = null,
    val busy: Boolean = false,
    val downloadingId: String? = null,
    val downloadProgress: Float? = null,
    val notice: String? = null,
    val error: String? = null,
)
