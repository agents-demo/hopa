package com.hopa.capabilities.bridge

import com.hopa.core.json.HopaJson
import com.hopa.core.ports.InstalledApp
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * The client half of the bridge contract: one bearer token, per-method
 * timeouts, one refresh on 401, and messages that never print the token.
 */
class BridgeClient(
    baseUrl: String,
    private var token: String,
    private val refresh: suspend () -> String? = { null },
) {
    private val base = normalise(baseUrl)
    private val http = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(45, TimeUnit.SECONDS)
        .build()

    suspend fun health(): JsonObject = call("GET", "/health", auth = false, timeout = 8)

    suspend fun pair(code: String): BridgeSession {
        val payload = call(
            method = "POST",
            path = "/pair",
            body = """{"code":${quote(code)}}""",
            auth = false,
            timeout = 15,
        )
        return session(payload)
    }

    suspend fun refreshSession(refresh: String): BridgeSession {
        val payload = call(
            method = "POST",
            path = "/refresh",
            body = """{"refresh":${quote(refresh)}}""",
            auth = false,
            timeout = 15,
        )
        return session(payload)
    }

    private fun session(payload: JsonObject): BridgeSession = BridgeSession(
        token = payload["token"]?.jsonPrimitive?.contentOrNull.orEmpty(),
        refresh = payload["refresh"]?.jsonPrimitive?.contentOrNull.orEmpty(),
        expiresIn = payload["expires_in"]?.jsonPrimitive?.contentOrNull?.toLongOrNull() ?: 0,
    )

    suspend fun whoami(): JsonObject = call("GET", "/whoami", timeout = 8)

    suspend fun observe(): JsonObject = call("POST", "/observe", body = "{}", timeout = 45)

    suspend fun foreground(): String =
        call("POST", "/foreground", body = "{}", timeout = 20)["bundle"]?.jsonPrimitive
            ?.contentOrNull.orEmpty()

    suspend fun tap(x: Int, y: Int) {
        call("POST", "/tap", body = """{"x":$x,"y":$y}""", timeout = 20)
    }

    suspend fun type(text: String, x: Int? = null, y: Int? = null) {
        val payload = buildJsonObject {
            put("text", text)
            if (x != null) put("x", x)
            if (y != null) put("y", y)
        }
        call("POST", "/type", body = payload.toString(), timeout = 20)
    }

    suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int = 600) {
        val payload = buildJsonObject {
            put("from_x", fromX)
            put("from_y", fromY)
            put("to_x", toX)
            put("to_y", toY)
            put("velocity", velocity)
        }
        call("POST", "/swipe", body = payload.toString(), timeout = 20)
    }

    suspend fun launch(bundle: String): JsonObject =
        call("POST", "/launch", body = """{"bundle":${quote(bundle)}}""", timeout = 20)

    suspend fun stop(bundle: String) {
        call("POST", "/stop", body = """{"bundle":${quote(bundle)}}""", timeout = 20)
    }

    suspend fun key(name: String, count: Int = 1) {
        call("POST", "/key", body = """{"name":${quote(name)},"count":$count}""", timeout = 20)
    }

    suspend fun screenshot(): ByteArray {
        val payload = call("POST", "/screenshot", body = "{}", timeout = 45)
        val encoded = payload["image"]?.jsonPrimitive?.contentOrNull.orEmpty()
        return java.util.Base64.getDecoder().decode(encoded)
    }

    suspend fun apps(): List<InstalledApp> {
        val payload = call("POST", "/apps", body = "{}", timeout = 20)
        return payload["apps"]?.jsonArray.orEmpty().mapNotNull { entry ->
            val item = entry.jsonObject
            val bundle = item["bundle"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
            InstalledApp(
                packageName = bundle,
                label = item["label"]?.jsonPrimitive?.contentOrNull ?: bundle,
            )
        }
    }

    suspend fun chats(): kotlinx.serialization.json.JsonObject =
        call("GET", "/chats", timeout = 45)

    suspend fun postChats(
        sessions: kotlinx.serialization.json.JsonArray,
    ): kotlinx.serialization.json.JsonObject = call(
        method = "POST",
        path = "/chats",
        body = buildJsonObject {
            put("sessions", sessions)
        }.toString(),
        timeout = 45,
    )

    private suspend fun call(
        method: String,
        path: String,
        body: String? = null,
        auth: Boolean = true,
        timeout: Long = 20,
        retried: Boolean = false,
    ): JsonObject = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(base + path)
            .apply {
                if (auth) header("Authorization", "Bearer $token")
                when (method) {
                    "GET" -> get()
                    else -> post((body ?: "{}").toRequestBody(JSON))
                }
            }
            .build()
        val client = http.newBuilder().readTimeout(timeout, TimeUnit.SECONDS).build()
        val response = try {
            client.newCall(request).execute()
        } catch (error: IOException) {
            throw BridgeException(scrub("bridge unreachable: ${error.message}"))
        }
        response.use {
            val text = it.body?.string().orEmpty()
            if (it.code == 401 && auth && !retried) {
                val next = refresh()
                if (!next.isNullOrBlank()) {
                    token = next
                    return@withContext call(method, path, body, auth, timeout, retried = true)
                }
            }
            if (!it.isSuccessful) {
                throw BridgeException(scrub("bridge HTTP ${it.code}: ${text.take(160)}"))
            }
            try {
                HopaJson.element.parseToJsonElement(text).jsonObject
            } catch (error: Exception) {
                throw BridgeException(scrub("bridge returned no JSON: ${text.take(80)}"))
            }
        }
    }

    /** Nothing a bridge error prints may contain the token or a full URL. */
    private fun scrub(message: String): String =
        message.replace(token, "<token>").replace(base, "<bridge>")

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()

        fun normalise(value: String): String {
            val trimmed = value.trim().trimEnd('/')
            return if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
                trimmed
            } else {
                "http://$trimmed"
            }
        }

        fun quote(value: String): String =
            "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    }
}
