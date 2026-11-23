package com.hopa.sidecar.backend

import java.util.Base64

/** The household content key is 32 bytes; anything else is a broken session. */
internal const val CONTENT_KEY_BYTES = 32

/** Decodes the stored content key; null means the file cannot be used. */
internal fun backendContentKey(session: BackendSession): ByteArray? =
    runCatching { Base64.getDecoder().decode(session.contentKeyBase64) }
        .getOrNull()
        ?.takeIf { it.size == CONTENT_KEY_BYTES }
