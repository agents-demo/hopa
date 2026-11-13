package com.hopa.capabilities.llm

import com.hopa.core.json.HopaJson
import com.hopa.core.model.ModelPort
import com.hopa.core.model.ModelReply
import com.hopa.core.model.ModelRequest
import com.hopa.core.model.ModelUsage
import java.io.IOException
import java.util.concurrent.TimeUnit
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
            put("reasoning_effort", request.reasoningEffort)
            putJsonArray("messages") {
                request.messages.forEach { message ->
                    add(
                        buildJsonObject {
                            put("role", message.role)
                            put("content", message.content)
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

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}
