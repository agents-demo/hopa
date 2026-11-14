package com.hopa.app.share

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.hopa.data.sessions.Attachment
import com.hopa.data.sessions.AttachmentRules
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Copies one inbound share into app storage.
 *
 * The caller gets either an [Attachment] whose bytes are already on disk, or a
 * notice. Nothing is ever larger than [AttachmentRules.MAX_BYTES]; a stream
 * that grows past the cap is stopped mid-copy and deleted.
 */
class AttachmentIntake(private val context: Context) {
    suspend fun accept(uri: Uri, hint: String? = null): IntakeResult = withContext(Dispatchers.IO) {
        val mime = runCatching { context.contentResolver.getType(uri) }
            .getOrNull()
            ?.takeIf { it.isNotBlank() }
            ?: hint?.takeIf { it.isNotBlank() && it != "*/*" }
            ?: "application/octet-stream"
        val name = displayName(uri)
        if (declaredSize(uri) > AttachmentRules.MAX_BYTES) {
            return@withContext IntakeResult(notice = AttachmentRules.TOO_LARGE)
        }
        val directory = File(context.filesDir, DIRECTORY).apply { mkdirs() }
        val file = File(directory, "${System.currentTimeMillis()}-${safeName(name)}")
        val copied = runCatching {
            context.contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output ->
                    var total = 0L
                    val buffer = ByteArray(8 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) {
                            break
                        }
                        total += read
                        if (total > AttachmentRules.MAX_BYTES) {
                            throw TooLarge()
                        }
                        output.write(buffer, 0, read)
                    }
                    total
                }
            } ?: throw IllegalStateException("no stream")
        }
        copied.fold(
            onSuccess = { bytes ->
                IntakeResult(Attachment(name = name, mime = mime, bytes = bytes, path = file.absolutePath))
            },
            onFailure = { error ->
                file.delete()
                IntakeResult(
                    notice = if (error is TooLarge) {
                        AttachmentRules.TOO_LARGE
                    } else {
                        AttachmentRules.UNREADABLE
                    },
                )
            },
        )
    }

    /** Remove a shared file the user discarded before sending it. */
    suspend fun delete(attachment: Attachment) = withContext(Dispatchers.IO) {
        runCatching { File(attachment.path).delete() }
        Unit
    }

    private fun displayName(uri: Uri): String {
        val fromProvider = runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(0) else null
                }
        }.getOrNull()
        return fromProvider?.takeIf { it.isNotBlank() } ?: "shared-file"
    }

    private fun declaredSize(uri: Uri): Long = runCatching {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else 0L
            }
    }.getOrNull() ?: 0L

    private fun safeName(name: String): String =
        name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(60).ifBlank { "shared-file" }

    private class TooLarge : Exception()

    private companion object {
        const val DIRECTORY = "attachments"
    }
}
