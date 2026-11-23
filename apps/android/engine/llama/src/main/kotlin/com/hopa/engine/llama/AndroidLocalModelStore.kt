package com.hopa.engine.llama

import android.content.Context
import android.net.Uri
import com.hopa.inference.local.FileModelStore
import com.hopa.inference.local.ImportFailure
import com.hopa.inference.local.ImportOutcome
import com.hopa.inference.local.InstalledModel
import com.hopa.inference.local.ModelSpec
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * The store over `filesDir/models`.
 *
 * Both paths end in the same place: [FileModelStore] verifies the size and the
 * digest and moves a file into place only when they match, so a half-downloaded
 * or substituted file never becomes a model. Import reads a document the person
 * picked; download writes `filesDir/model-downloads/<id>.gguf.part` and resumes
 * it with a `Range` request when a previous attempt was cut short.
 */
class AndroidLocalModelStore(context: Context) : LocalModelStore {
    private val context = context.applicationContext
    private val store = FileModelStore(File(context.filesDir, DIRECTORY))
    private val downloads = File(context.filesDir, DOWNLOADS)
    private val client = OkHttpClient()

    override suspend fun installed(): List<InstalledModel> =
        withContext(Dispatchers.IO) { store.installed() }

    override suspend fun totalBytes(): Long =
        withContext(Dispatchers.IO) { store.totalBytes() }

    override suspend fun import(uri: Uri, spec: ModelSpec): ImportOutcome =
        withContext(Dispatchers.IO) {
            val input = context.contentResolver.openInputStream(uri)
                ?: return@withContext ImportOutcome.Empty
            input.use { store.import(it, spec) }
        }

    override suspend fun download(
        spec: ModelSpec,
        onProgress: (Long, Long) -> Unit,
    ): ImportOutcome = withContext(Dispatchers.IO) {
        if (spec.url.isBlank()) {
            return@withContext ImportOutcome.Failed(ImportFailure.NETWORK)
        }
        downloads.mkdirs()
        val part = File(downloads, "${spec.id}.gguf.part")
        var existing = if (part.isFile) part.length() else 0L
        if (spec.bytes > 0 && existing > spec.bytes) {
            part.delete()
            existing = 0
        }
        if (spec.bytes > 0 && existing == spec.bytes) {
            // A previous attempt finished the bytes but not the move.
            val adopted = store.adopt(part, spec)
            if (adopted is ImportOutcome.Imported) part.delete()
            return@withContext adopted
        }
        val request = Request.Builder()
            .url(spec.url)
            .get()
            .apply { if (existing > 0) header("Range", "bytes=$existing-") }
            .build()
        runCatching {
            client.newCall(request).execute().use { response ->
                val body = response.body ?: return@use ImportOutcome.Failed(ImportFailure.NETWORK)
                if (!response.isSuccessful) {
                    if (response.code == 416) part.delete()
                    return@use ImportOutcome.Failed(ImportFailure.NETWORK)
                }
                val resuming = existing > 0 && response.code == 206
                if (!resuming) {
                    part.delete()
                    existing = 0
                }
                val total = if (body.contentLength() > 0) {
                    existing + body.contentLength()
                } else {
                    spec.bytes
                }
                val needed = (total - existing).coerceAtLeast(0)
                if (needed > context.filesDir.usableSpace) {
                    part.delete()
                    return@use ImportOutcome.Failed(ImportFailure.STORAGE)
                }
                var written = existing
                onProgress(written, total)
                body.byteStream().use { input ->
                    FileOutputStream(part, resuming).use { output ->
                        val buffer = ByteArray(BUFFER)
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            written += read
                            onProgress(written, total)
                        }
                    }
                }
                if (spec.bytes > 0 && part.length() < spec.bytes) {
                    // Keep the part: the next attempt resumes from here.
                    return@use ImportOutcome.Failed(ImportFailure.NETWORK)
                }
                val adopted = store.adopt(part, spec)
                if (adopted is ImportOutcome.Imported) part.delete()
                adopted
            }
        }.getOrElse { error ->
            if (error is IOException) {
                ImportOutcome.Failed(ImportFailure.NETWORK)
            } else {
                ImportOutcome.Failed(ImportFailure.STORAGE)
            }
        }
    }

    override suspend fun delete(id: String): Boolean =
        withContext(Dispatchers.IO) {
            File(downloads, "$id.gguf.part").delete()
            store.delete(id)
        }

    override suspend fun cleanup(keep: Set<String>): Int =
        withContext(Dispatchers.IO) { store.cleanup(keep) }

    private companion object {
        const val DIRECTORY = "models"
        const val DOWNLOADS = "model-downloads"
        const val BUFFER = 64 * 1024
    }
}
