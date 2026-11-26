package com.hopa.mmbert

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/** Downloads the ranker once; the settings page shows the size first. */
class MmBertInstaller(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(300, TimeUnit.SECONDS)
        .build()

    fun installed(): Boolean {
        val file = MmBertModel.file(context)
        val ok = file.isFile && file.length() > 0
        android.util.Log.i(
            "HopaTree",
            "model ${file.absolutePath} file=${file.isFile} bytes=${file.length()} ok=$ok",
        )
        return ok
    }

    fun bytes(): Long = MmBertModel.file(context).let { if (it.isFile) it.length() else 0L }

    suspend fun download(onProgress: (Long, Long) -> Unit): Result<File> = withContext(Dispatchers.IO) {
        runCatching {
            val directory = MmBertModel.directory(context).apply { mkdirs() }
            val part = File(directory, "${MmBertModel.FILE}.part")
            if (part.exists()) part.delete()

            val request = Request.Builder()
                .url(MmBertModel.URL)
                .header("User-Agent", "HOPA-Android")
                .build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) error("HTTP ${response.code}")
                val body = response.body ?: error("empty response")
                val total = body.contentLength()
                val digest = MessageDigest.getInstance("SHA-256")
                body.byteStream().use { input ->
                    FileOutputStream(part).use { output ->
                        val buffer = ByteArray(256 * 1024)
                        var done = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            output.write(buffer, 0, read)
                            digest.update(buffer, 0, read)
                            done += read
                            onProgress(done, total)
                        }
                    }
                }
                val sha = digest.digest().joinToString("") { "%02x".format(it) }
                if (MmBertModel.SHA256.isNotBlank() && !sha.equals(MmBertModel.SHA256, true)) {
                    part.delete()
                    error("checksum mismatch")
                }
                val target = MmBertModel.file(context)
                if (target.exists()) target.delete()
                if (!part.renameTo(target)) error("could not move the model into place")
                target
            }
        }
    }

    fun delete(): Boolean {
        val file = MmBertModel.file(context)
        val part = File(file.parentFile, "${file.name}.part")
        part.delete()
        return !file.exists() || file.delete()
    }
}
