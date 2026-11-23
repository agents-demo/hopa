package com.hopa.sidecar.cli

import java.nio.file.Path

/** `HOPA_DATA_DIR` wins over the default, so a test or an installer can pin it. */
internal fun defaultDataDir(): Path =
    System.getenv("HOPA_DATA_DIR")
        ?.takeIf { it.isNotBlank() }
        ?.let { Path.of(it) }
        ?: Path.of(System.getProperty("user.home"), ".hopa", "windows")

/** `--pair-backend <url>`; a missing or flag-looking value is ignored. */
internal fun pairBackendUrl(args: Array<String>): String? {
    val index = args.indexOf("--pair-backend")
    if (index < 0) return null
    return args.getOrNull(index + 1)?.takeIf { it.isNotBlank() && !it.startsWith("--") }
}
