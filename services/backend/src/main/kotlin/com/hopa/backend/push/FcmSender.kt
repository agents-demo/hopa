package com.hopa.backend.push

import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * FCM HTTP v1, data-only and high priority. The payload carries a task id and a
 * trace id; never a goal, a summary or anything the phone would render.
 */
class FcmSender(
    private val projectId: String,
    private val timeoutMs: Long = 5_000,
    private val baseUrl: String = "https://fcm.googleapis.com",
    private val auth: FcmAuth,
    private val http: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofMillis(timeoutMs))
        .build(),
) : PushSender {
    override fun send(token: String, data: Map<String, String>): PushOutcome {
        val payload = buildJsonObject {
            put(
                "message",
                buildJsonObject {
                    put("token", token)
                    put(
                        "data",
                        buildJsonObject { data.forEach { (key, value) -> put(key, value) } },
                    )
                    put(
                        "android",
                        buildJsonObject {
                            put("priority", "high")
                            put("ttl", "300s")
                        },
                    )
                },
            )
        }.toString()

        return try {
            val request = HttpRequest.newBuilder(
                URI.create("$baseUrl/v1/projects/$projectId/messages:send"),
            )
                .header("Authorization", "Bearer ${auth.bearerToken()}")
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(timeoutMs))
                .POST(HttpRequest.BodyPublishers.ofString(payload))
                .build()
            val response = http.send(request, HttpResponse.BodyHandlers.ofString())
            when {
                response.statusCode() in 200..299 -> PushOutcome.Delivered
                response.statusCode() == 404 && response.body().contains("UNREGISTERED") ->
                    PushOutcome.InvalidToken

                else -> PushOutcome.Retryable
            }
        } catch (_: Exception) {
            PushOutcome.Retryable
        }
    }
}
