package com.hopa.backend.push

import com.hopa.backend.http.RateLimiter
import java.util.concurrent.ConcurrentHashMap

/**
 * Six wakes a minute per device, and one wake per task in the dedupe window.
 * Both are process-local: v0 is one container, and the durable record is the
 * task row, not the push.
 */
class GuardedPush(
    private val sender: PushSender,
    wakesPerMinute: Int = 6,
    private val clock: () -> Long = System::currentTimeMillis,
) : PushPort {
    private val limiter = RateLimiter(wakesPerMinute, 60_000, clock)
    private val woken = ConcurrentHashMap<String, Long>()

    override fun wake(deviceId: String, taskId: String, traceId: String, pushToken: String): PushOutcome {
        val now = clock()
        woken.entries.removeIf { it.value <= now - 60_000 }
        if (woken.containsKey(taskId)) return PushOutcome.Skipped
        if (!limiter.allow(deviceId)) return PushOutcome.Skipped

        woken[taskId] = now
        return sender.send(pushToken, mapOf("taskId" to taskId, "traceId" to traceId))
    }
}
