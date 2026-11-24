package com.hopa.inference.client

import com.hopa.contracts.json.HopaJson
import com.hopa.contracts.model.ModelPort
import com.hopa.contracts.model.ModelReply
import com.hopa.contracts.model.ModelRequest
import com.hopa.contracts.model.ModelUsage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

class OpenAiClient(
    private val endpoint: String,
    private val apiKey: String,
    private val modelName: String,
) : ModelPort {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    override suspend fun complete(request: ModelRequest): ModelReply = withContext(Dispatchers.IO) {
        val payload = buildJsonObject {
            put("model", modelName)
            put("max_tokens", request.maxTokens)
            // Plain OpenAI-compatible servers (DeepSeek, Ollama, LM Studio,
            // vLLM) reject fields they do not know, so only send it when set.
            if (request.reasoningEffort.isNotBlank()) {
                put("reasoning_effort", request.reasoningEffort)
            }
            putJsonArray("messages") {
                val lastUser = request.messages.indexOfLast { it.role == "user" }
                request.messages.forEachIndexed { index, message ->
                    add(
                        buildJsonObject {
                            put("role", message.role)
                            if (index == lastUser && request.images.isNotEmpty()) {
                                putJsonArray("content") {
                                    add(
                                        buildJsonObject {
                                            put("type", "text")
                                            put("text", message.content)
                                        },
                                    )
                                    request.images.forEach { frame ->
                                        add(
                                            buildJsonObject {
                                                put("type", "image_url")
                                                put(
                                                    "image_url",
                                                    buildJsonObject {
                                                        put(
                                                            "url",
                                                            "data:${imageMime(frame)};base64,$frame",
                                                        )
                                                    },
                                                )
                                            },
                                        )
                                    }
                                }
                            } else {
                                put("content", message.content)
                            }
                        },
                    )
                }
            }
        }
        val httpRequest = Request.Builder()
            .url(url())
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("Content-Type", "application/json")
            .post(payload.toString().toRequestBody(JSON))
            .build()

        client.newCall(httpRequest).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IOException("model HTTP ${response.code}: ${body.take(300)}")
            }
            val root = HopaJson.element.parseToJsonElement(body).jsonObject
            val content = root["choices"]
                ?.jsonArray
                ?.firstOrNull()
                ?.jsonObject
                ?.get("message")
                ?.jsonObject
                ?.get("content")
                ?.jsonPrimitive
                ?.contentOrNull
                .orEmpty()
            if (content.isBlank()) {
                throw IOException("model returned an empty answer")
            }
            val usage = root["usage"]?.jsonObject
            ModelReply(
                text = content.trim(),
                usage = ModelUsage(
                    promptTokens = usage?.get("prompt_tokens")?.jsonPrimitive?.intOrNull ?: 0,
                    completionTokens = usage?.get("completion_tokens")?.jsonPrimitive?.intOrNull ?: 0,
                    totalTokens = usage?.get("total_tokens")?.jsonPrimitive?.intOrNull ?: 0,
                ),
            )
        }
    }

    private fun url(): String {
        val base = endpoint.trimEnd('/')
        return if (base.endsWith("/chat/completions")) base else "$base/chat/completions"
    }

    /**
     * Android screenshots are JPEG and Windows screenshots are PNG. Sending a
     * PNG body as `image/jpeg` makes some providers drop the frame; the
     * signature is cheap to read and keeps both clients honest.
     */
    private fun imageMime(frame: String): String = when {
        frame.startsWith("iVBORw0KGgo") -> "image/png"
        frame.startsWith("/9j/") -> "image/jpeg"
        else -> "image/jpeg"
    }

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}
