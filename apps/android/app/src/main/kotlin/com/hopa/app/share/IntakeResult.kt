package com.hopa.app.share

import com.hopa.data.sessions.Attachment

/** The outcome of one inbound share: an attachment, or the reason there is none. */
data class IntakeResult(
    val attachment: Attachment? = null,
    val notice: String? = null,
)
