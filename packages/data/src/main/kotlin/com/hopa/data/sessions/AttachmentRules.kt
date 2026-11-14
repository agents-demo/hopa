package com.hopa.data.sessions

import java.util.Locale

/** What an inbound share may be, and how the chat talks about it. */
object AttachmentRules {
    /** The shared max for one attachment, from the plan's data caps. */
    const val MAX_BYTES: Long = 4L * 1024 * 1024

    const val TOO_LARGE: String =
        "That file is larger than 4 MiB, so HOPA did not attach it."
    const val UNREADABLE: String = "HOPA could not read that file."

    fun isImage(mime: String): Boolean = mime.startsWith("image/")

    /** The text a message carries when the user sent a file without a caption. */
    fun describe(attachment: Attachment): String =
        if (isImage(attachment.mime)) {
            "Shared an image: ${attachment.name}"
        } else {
            "Shared a file: ${attachment.name}"
        }

    fun humanSize(bytes: Long): String = when {
        bytes >= 1024L * 1024L ->
            String.format(Locale.ROOT, "%.1f MB", bytes / (1024.0 * 1024.0))
        bytes >= 1024L -> "${bytes / 1024} KB"
        else -> "$bytes B"
    }
}
