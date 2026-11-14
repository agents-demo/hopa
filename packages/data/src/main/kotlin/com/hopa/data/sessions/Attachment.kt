package com.hopa.data.sessions

import kotlinx.serialization.Serializable

/** A file the user shared into a chat. The bytes live in app storage. */
@Serializable
data class Attachment(
    val name: String,
    val mime: String,
    val bytes: Long,
    val path: String,
)
