package com.hopa.backend.harness

import com.hopa.backend.push.FcmSender
import com.hopa.backend.push.GuardedPush
import com.hopa.backend.push.PushPort
import com.hopa.backend.push.StaticFcmAuth
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** An FCM HTTP v1 endpoint that records the exact request body. */
class FakeFcm : AutoCloseable {
    private val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    val requests = CopyOnWriteArrayList<String>()

    val url: String
        get() = "http://127.0.0.1:${server.address.port}"

    init {
        server.createContext("/v1/projects/hopa-test/messages:send") { exchange ->
            val body = exchange.requestBody.readBytes().toString(StandardCharsets.UTF_8)
            requests += body
            val token = Json.parseToJsonElement(body)
                .jsonObject["message"]!!.jsonObject["token"]!!.jsonPrimitive.content
            val (status, response) = if (token.startsWith("dead-")) {
                404 to """{"error":{"status":"UNREGISTERED"}}"""
            } else {
                200 to """{"name":"projects/hopa-test/messages/1"}"""
            }
            val bytes = response.toByteArray(StandardCharsets.UTF_8)
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(status, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
    }

    fun push(projectId: String = "hopa-test"): PushPort = GuardedPush(
        FcmSender(projectId = projectId, baseUrl = url, auth = StaticFcmAuth("test-token")),
    )

    override fun close() {
        server.stop(0)
    }
}
