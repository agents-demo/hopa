package com.hopa.backend.http

import java.util.concurrent.ConcurrentHashMap

/**
 * Sliding-window counter. Per-process on purpose: v0 runs one container, and a
 * shared limiter would be Redis (which the RFC rules out for week 1).
 */
class RateLimiter(
    private val limit: Int,
    private val windowMs: Long,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val hits = ConcurrentHashMap<String, MutableList<Long>>()

    fun allow(key: String): Boolean = synchronized(hits) {
        val now = clock()
        val window = hits.getOrPut(key) { mutableListOf() }
        window.removeAll { it <= now - windowMs }
        if (window.size >= limit) {
            false
        } else {
            window.add(now)
            true
        }
    }
}
