package com.hopa.data.sessions

/** A file the user shared into a chat. The bytes live in app storage. */
data class Attachment(
    val name: String,
    val mime: String,
    val bytes: Long,
    val path: String,
)
