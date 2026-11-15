package com.hopa.backend.gateway

import com.hopa.backend.ServerConfig
import com.hopa.backend.auth.DeviceIdentity
import com.hopa.backend.protocol.DecodeResult
import com.hopa.backend.protocol.Envelope
import com.hopa.backend.protocol.EnvelopeValidator
import com.hopa.backend.protocol.GatewayCodec
import com.hopa.backend.tasks.InMemoryTaskStore
import com.hopa.backend.tasks.RouteResult
import com.hopa.backend.tasks.TaskRecord
import com.hopa.backend.tasks.TaskRouter
import io.ktor.http.HttpHeaders
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.request.header
import io.ktor.server.routing.routing
import io.ktor.server.websocket.WebSockets
import io.ktor.server.websocket.pingPeriod
import io.ktor.server.websocket.timeout
import io.ktor.server.websocket.webSocket
import io.ktor.websocket.CloseReason
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import java.util.UUID
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

fun Application.gatewayRoutes(
    config: ServerConfig,
    registry: DeviceRegistry = DeviceRegistry(),
    router: TaskRouter = TaskRouter(
        store = config.tasks,
        registry = registry,
        devices = config.devices,
        log = config.log,
        push = config.push,
    ),
) {
    install(WebSockets) {
        pingPeriod = 25.seconds
        timeout = 90.seconds
        // Four times the contract cap: a frame the client should not have sent
        // still reaches the validator, which answers E_SCHEMA. Ktor only closes
        // the socket itself beyond this, so the limit is a fail-safe, not the
        // contract.
        maxFrameSize = EnvelopeValidator.MAX_FRAME_BYTES * 4L
    }

    routing {
        webSocket("/v1/gateway") {
            val token = call.request.header(HttpHeaders.Authorization)
                ?.removePrefix("Bearer ")
                ?.trim()
            val identity = token?.takeIf { it.isNotEmpty() }?.let(config.auth::deviceFor)
            if (identity == null) {
                send(Frame.Text(GatewayCodec.encode(errorFrame("E_AUTH", "unknown or expired token"))))
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "E_AUTH"))
                return@webSocket
            }

            val outgoing = Channel<String>(Channel.BUFFERED)
            val writer = launch {
                for (text in outgoing) {

                    send(Frame.Text(text))
                }
            }
            val session = DeviceRegistry.Session(identity, outgoing)

            try {
                for (frame in incoming) {
                    if (frame !is Frame.Text) continue
                    val raw = frame.readText()
                    val decoded = GatewayCodec.decode(raw)
                    val failure = decoded as? DecodeResult.Failed
                    if (failure != null) {
                        outgoing.send(
                            GatewayCodec.encode(
                                errorFrame(failure.error.code, failure.error.message),
                            ),
                        )
                        continue
                    }

                    val envelope = (decoded as DecodeResult.Ok).envelope
                    val problem = EnvelopeValidator.validate(raw, envelope)
                    if (problem != null) {
                        outgoing.send(GatewayCodec.encode(errorFrame(problem.code, problem.message)))
                        continue
                    }

                    when (envelope.type) {
                        "device.hello" -> {
                            registry.join(session)
                            config.devices.touch(
                                identity.deviceId,
                                identity.householdId,
                                envelope.body["pushToken"]?.jsonPrimitive?.contentOrNull,
                                System.currentTimeMillis(),
                            )
                            val ids = registry.deviceIds(identity.householdId)
                            val peers = registry.peers(identity.householdId, identity.deviceId)
                            // The newcomer learns the roster from the ack; one
                            // event per join tells the others, so a replay or an
                            // interleaved handshake cannot announce it twice.
                            outgoing.send(
                                GatewayCodec.encode(
                                    helloAck(identity.deviceId, queued = 0, peers = ids),
                                ),
                            )
                            peers.forEach { peer ->
                                peer.outgoing.trySend(
                                    GatewayCodec.encode(
                                        presence(identity.deviceId, online = true, ids),
                                    ),
                                )
                            }
                            router.deliverPending(identity.deviceId, identity.householdId)
                        }

                        "ping" -> outgoing.send(
                            GatewayCodec.encode(serverFrame("pong", identity.deviceId)),
                        )

                        else -> {
                            if (envelope.type.startsWith("task.") &&
                                !config.messageLimit.allow(identity.deviceId)
                            ) {
                                outgoing.send(
                                    GatewayCodec.encode(errorFrame("E_RATE", "too many messages")),
                                )
                                continue
                            }
                            when (val result = router.route(identity, envelope)) {
                                is RouteResult.Accepted -> outgoing.send(
                                    GatewayCodec.encode(
                                        acceptedFrame(identity.deviceId, result.task, result.duplicate),
                                    ),
                                )

                                is RouteResult.Refused -> outgoing.send(
                                    GatewayCodec.encode(
                                        errorFrame(
                                            result.error.code,
                                            result.error.message,
                                            trace = result.trace,
                                        ),
                                    ),
                                )
                            }
                        }
                    }
                }
            } finally {
                registry.leave(session)
                val remaining = registry.deviceIds(identity.householdId)
                registry.peers(identity.householdId, identity.deviceId).forEach { peer ->

                    peer.outgoing.trySend(
                        GatewayCodec.encode(
                            presence(identity.deviceId, online = false, remaining),
                        ),
                    )
                }
                outgoing.close()
                writer.cancel()
            }
        }
    }
}

/** Server-authored frame. The id is ours; [to] is the device that receives it. */
private fun serverFrame(
    type: String,
    to: String?,
    body: JsonObject = JsonObject(emptyMap()),
    trace: String? = null,
): Envelope = Envelope(
    v = 1,
    id = UUID.randomUUID().toString(),
    type = type,
    ts = System.currentTimeMillis(),
    trace = trace,
    to = to,
    body = body,
)

private fun errorFrame(code: String, message: String, trace: String? = null): Envelope =
    serverFrame(
        type = "error",
        to = null,
        trace = trace,
        body = buildJsonObject {
            put("code", code)
            put("message", message)
            put("retryable", code == "E_QUEUE" || code == "E_RATE")
        },
    )

private fun acceptedFrame(deviceId: String, task: TaskRecord, duplicate: Boolean): Envelope =
    serverFrame(
        type = "task.ack",
        to = deviceId,
        trace = task.trace,
        body = buildJsonObject {
            put("task", task.id)
            put("state", task.state)
            put("duplicate", duplicate)
        },
    )

private fun helloAck(deviceId: String, queued: Int, peers: List<String>): Envelope =
    serverFrame(
        type = "device.hello.ack",
        to = deviceId,
        body = buildJsonObject {
            put("session", UUID.randomUUID().toString())
            put("serverTime", System.currentTimeMillis())
            put("heartbeatSec", 25)
            put("queued", queued)
            put("peers", JsonArray(peers.map { kotlinx.serialization.json.JsonPrimitive(it) }))
        },
    )

private fun presence(deviceId: String, online: Boolean, peers: List<String>): Envelope =
    serverFrame(
        type = "presence",
        to = null,
        body = buildJsonObject {
            put("device", deviceId)
            put("online", online)
            put("peers", JsonArray(peers.map { kotlinx.serialization.json.JsonPrimitive(it) }))
        },
    )
