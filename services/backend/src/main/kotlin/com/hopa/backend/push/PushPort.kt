package com.hopa.backend.push

enum class PushOutcome { Delivered, InvalidToken, Retryable, Skipped }

/** The FCM call itself, without rate limits or deduplication. */
fun interface PushSender {
    fun send(token: String, data: Map<String, String>): PushOutcome
}

/** A wake for one offline device. The server never puts message content here. */
fun interface PushPort {
    fun wake(deviceId: String, taskId: String, traceId: String, pushToken: String): PushOutcome

    companion object {
        val None = PushPort { _, _, _, _ -> PushOutcome.Skipped }
    }
}
