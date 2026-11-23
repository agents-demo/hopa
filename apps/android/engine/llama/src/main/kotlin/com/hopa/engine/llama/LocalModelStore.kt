package com.hopa.engine.llama

import android.net.Uri
import com.hopa.inference.local.ImportOutcome
import com.hopa.inference.local.InstalledModel
import com.hopa.inference.local.ModelSpec

/**
 * The model files this phone keeps.
 *
 * The interface exists so the settings view model is tested on the JVM with a
 * fake, and so nothing outside this module knows about `filesDir` or `Uri`.
 * Every call is suspend because every implementation touches the disk.
 */
interface LocalModelStore {
    suspend fun installed(): List<InstalledModel>

    suspend fun totalBytes(): Long

    suspend fun import(uri: Uri, spec: ModelSpec): ImportOutcome

    suspend fun download(spec: ModelSpec, onProgress: (Long, Long) -> Unit): ImportOutcome

    suspend fun delete(id: String): Boolean

    suspend fun cleanup(keep: Set<String>): Int
}
