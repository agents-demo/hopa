package com.hopa.inference.local

import java.net.URI

/**
 * The only endpoint an on-device model may use.
 *
 * Windows runs llama.cpp in its own process, so the engine reaches it over
 * HTTP. That server must stay on this machine: a non-loopback address would
 * send the screen and the goal to someone else while the UI still said
 * "on-device". The host is parsed, not prefix-matched, so
 * `http://127.0.0.1.example.com` is rejected.
 */
object LocalEndpoint {
    fun isLoopback(url: String): Boolean {
        val uri = runCatching { URI(url.trim()) }.getOrNull() ?: return false
        if (!uri.scheme.equals("http", ignoreCase = true)) {
            return false
        }
        return when (val host = uri.host?.lowercase()) {
            "127.0.0.1", "localhost", "::1", "[::1]" -> true
            else -> false
        }
    }
}
