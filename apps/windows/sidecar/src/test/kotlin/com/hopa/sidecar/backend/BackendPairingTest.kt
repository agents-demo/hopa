package com.hopa.sidecar.backend

import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.BitMatrix
import com.google.zxing.common.HybridBinarizer
import com.hopa.backend.crypto.KeyWrap
import com.hopa.backend.pairing.X25519Keys
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.security.MessageDigest
import java.util.ArrayDeque
import java.util.Base64
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * The PC half of admission: mint, render the QR, poll until the phone vouches,
 * claim, then unwrap the 32-byte household key with the vouching phone's public
 * key. MockWebServer plays the backend; the wrap is produced by the real
 * [KeyWrap], so the test proves the byte layout end to end.
 */
class BackendPairingTest {
    private val contentKey = KeyWrap.generateContentKey()
    private val phonePrivateKey = X25519Keys.generatePrivateKey()
    private val phonePublicKey = X25519Keys.publicKeyBytes(phonePrivateKey)
    private val qr = "hopa://pair?v=1&s=secret-1&u=wss://example.test/v1/gateway"

    @Test
    fun `admit mints, polls, claims and unwraps the household key`() = runTest {
        val server = server(ResolveStep.State("pending"), ResolveStep.State("vouched"))
        try {
            val dataDir = Files.createTempDirectory("hopa-admit")
            val lines = mutableListOf<String>()
            val result = BackendPairing(dataDir, out = { lines += it })
                .admit(backendUrl(server), "Studio")

            assertArrayEquals(contentKey, result.contentKey)
            assertEquals(32, result.contentKey.size)
            assertEquals("d1", result.credentials.deviceId)
            assertEquals("h1", result.credentials.householdId)
            assertEquals("a1", result.credentials.accessToken)
            // The mint's QR is authoritative over the URL the caller typed.
            assertEquals("wss://example.test/v1/gateway", result.credentials.gatewayUrl)

            assertEquals(1, server.claimCount)
            assertEquals(2, server.resolveCount)
            assertTrue(server.mintBody.contains("\"platform\":\"windows\""))
            assertTrue(server.claimBody.contains("\"platform\":\"windows\""))
            assertTrue(server.claimBody.contains("\"alg\":\"x25519\""))

            // The printed link and Unicode blocks are the pending QR and decode
            // back to it; the PNG is transient and is gone after the claim.
            assertTrue(lines.contains(qr))
            val blocks = lines.first { line -> line.any { it == '▀' || it == '▄' || it == '█' } }
            assertEquals(qr, decodeBlocks(blocks))
            assertFalse(Files.exists(dataDir.resolve("pair-qr.png")))
            val expectedFingerprint = sha256Hex(server.pcPublicKey).take(8)
            assertTrue(lines.contains("fingerprint: $expectedFingerprint"))

            // The returned result never prints tokens or key material.
            assertFalse(result.toString().contains("a1"))
            assertFalse(result.toString().contains("r1"))
            assertFalse(result.toString().contains(Base64.getEncoder().encodeToString(contentKey)))

            val stored = BackendSessionStore(dataDir.resolve("backend-session.json")).load()!!
            assertEquals("d1", stored.deviceId)
            assertEquals("h1", stored.householdId)
            assertEquals("wss://example.test/v1/gateway", stored.gatewayUrl)
            assertArrayEquals(contentKey, Base64.getDecoder().decode(stored.contentKeyBase64))
            assertArrayEquals(
                server.pcPublicKey,
                X25519Keys.publicKeyBytes(Base64.getDecoder().decode(stored.privateKeyBase64)),
            )
        } finally {
            server.close()
        }
    }

    @Test
    fun `a 429 poll backs off and still succeeds`() {
        val server = server(
            ResolveStep.RateLimited,
            ResolveStep.State("pending"),
            ResolveStep.State("vouched"),
        )
        try {
            val dataDir = Files.createTempDirectory("hopa-admit-backoff")
            val sleeps = mutableListOf<Long>()
            val result = runBlocking {
                BackendPairing(dataDir, sleep = { sleeps += it })
                    .admit(backendUrl(server), "Studio")
            }

            assertArrayEquals(contentKey, result.contentKey)
            assertEquals(1, server.claimCount)
            assertEquals(3, server.resolveCount)
            assertEquals(listOf(10_000L, 5_000L), sleeps)
        } finally {
            server.close()
        }
    }

    @Test
    fun `an expired session fails clearly and never claims`() {
        val server = server(ResolveStep.State("expired"))
        try {
            val dataDir = Files.createTempDirectory("hopa-admit-expired")
            val pairing = BackendPairing(dataDir)
            val failure = assertThrows(IllegalStateException::class.java) {
                runBlocking { pairing.admit(backendUrl(server), "Studio") }
            }

            assertTrue(failure.message.orEmpty().contains("expired"))
            assertEquals(0, server.claimCount)
            assertEquals(1, server.resolveCount)
        } finally {
            server.close()
        }
    }

    @Test
    fun `a claimed session fails clearly and never claims again`() {
        val server = server(ResolveStep.State("claimed"))
        try {
            val dataDir = Files.createTempDirectory("hopa-admit-claimed")
            val failure = assertThrows(IllegalStateException::class.java) {
                runBlocking { BackendPairing(dataDir).admit(backendUrl(server), "Studio") }
            }

            assertTrue(failure.message.orEmpty().contains("already claimed"))
            assertEquals(0, server.claimCount)
            assertEquals(1, server.resolveCount)
        } finally {
            server.close()
        }
    }

    @Test
    fun `a session that is never vouched times out after five minutes`() {
        val server = serverDefaultingTo("pending")
        try {
            val dataDir = Files.createTempDirectory("hopa-admit-timeout")
            var clock = 0L
            val pairing = BackendPairing(
                dataDir,
                sleep = { clock += it },
                now = { clock },
            )
            val failure = assertThrows(IllegalStateException::class.java) {
                runBlocking { pairing.admit(backendUrl(server), "Studio") }
            }

            assertTrue(failure.message.orEmpty().contains("timed out"))
            assertEquals(0, server.claimCount)
            assertTrue(server.resolveCount >= 60)
        } finally {
            server.close()
        }
    }

    @Test
    fun `the default output keeps the pairing secret off stdout`() {
        val server = server(ResolveStep.State("pending"), ResolveStep.State("vouched"))
        val originalOut = System.out
        val originalErr = System.err
        val stdout = ByteArrayOutputStream()
        val stderr = ByteArrayOutputStream()
        System.setOut(PrintStream(stdout, true, StandardCharsets.UTF_8))
        System.setErr(PrintStream(stderr, true, StandardCharsets.UTF_8))
        try {
            val dataDir = Files.createTempDirectory("hopa-admit-stderr")
            runTest { BackendPairing(dataDir).admit(backendUrl(server), "Studio") }

            val out = stdout.toString(StandardCharsets.UTF_8)
            val err = stderr.toString(StandardCharsets.UTF_8)
            assertFalse(out.contains("secret-1"))
            assertFalse(out.contains(qr))
            assertTrue(err.contains(qr))
        } finally {
            System.setOut(originalOut)
            System.setErr(originalErr)
            server.close()
        }
    }

    private fun server(vararg steps: ResolveStep): FakeServer =
        server(steps.toList(), defaultState = "vouched")

    private fun serverDefaultingTo(state: String): FakeServer =
        server(emptyList(), defaultState = state)

    private fun server(steps: List<ResolveStep>, defaultState: String): FakeServer =
        FakeServer(contentKey, phonePrivateKey, phonePublicKey, qr, steps, defaultState)
            .also { it.start() }

    private fun backendUrl(server: FakeServer) =
        "ws://${server.hostName}:${server.port}/v1/gateway"

    private fun decodeBlocks(blocks: String): String {
        val rows = blocks.trimEnd('\n').split('\n')
        val width = rows.maxOf { it.length }
        val matrix = BitMatrix(width, rows.size * 2)
        rows.forEachIndexed { row, line ->
            line.forEachIndexed { x, glyph ->
                when (glyph) {
                    '█' -> {
                        matrix.set(x, row * 2)
                        matrix.set(x, row * 2 + 1)
                    }
                    '▀' -> matrix.set(x, row * 2)
                    '▄' -> matrix.set(x, row * 2 + 1)
                }
            }
        }
        return decodeImage(matrix, scale = 8)
    }

    private fun decodeImage(matrix: BitMatrix, scale: Int = 1): String {
        val image = BufferedImage(matrix.width * scale, matrix.height * scale, BufferedImage.TYPE_INT_RGB)
        for (y in 0 until image.height) {
            for (x in 0 until image.width) {
                image.setRGB(x, y, if (matrix[x / scale, y / scale]) 0x000000 else 0xFFFFFF)
            }
        }
        val pixels = IntArray(image.width * image.height)
        image.getRGB(0, 0, image.width, image.height, pixels, 0, image.width)
        val bitmap = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(image.width, image.height, pixels)))
        val reader = MultiFormatReader().apply {
            setHints(mapOf(DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE)))
        }
        return reader.decode(bitmap).text
    }

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    private sealed interface ResolveStep {
        data class State(val state: String) : ResolveStep
        data object RateLimited : ResolveStep
    }

    /**
     * Plays the backend. The claim response is built from the public key read out
     * of the mint request, exactly like the phone would: the wrap is real
     * X25519/AES-GCM for that PC key.
     */
    private class FakeServer(
        private val contentKey: ByteArray,
        private val phonePrivateKey: ByteArray,
        private val phonePublicKey: ByteArray,
        private val qr: String,
        steps: List<ResolveStep>,
        private val defaultState: String,
    ) : Dispatcher() {
        private val steps = ArrayDeque(steps)
        private val server = MockWebServer()

        lateinit var pcPublicKey: ByteArray
        var resolveCount = 0
        var claimCount = 0
        var mintBody = ""
        var claimBody = ""

        val hostName: String get() = server.hostName
        val port: Int get() = server.port

        override fun dispatch(request: RecordedRequest): MockResponse = when (request.path) {
            "/v1/pair/pending" -> {
                mintBody = request.body.readUtf8()
                val body = Json.parseToJsonElement(mintBody).jsonObject
                pcPublicKey = Base64.getUrlDecoder().decode(body["publicKey"]!!.jsonPrimitive.content)
                json(
                    201,
                    buildJsonObject {
                        put("sessionId", "sid")
                        put("secret", "secret-1")
                        put("qr", qr)
                        put("expiresAt", "2026-11-17T00:05:00Z")
                    },
                )
            }

            "/v1/pair/pending/resolve" -> {
                resolveCount++
                when (val step = steps.pollFirst() ?: ResolveStep.State(defaultState)) {
                    is ResolveStep.RateLimited -> MockResponse().setResponseCode(429).setBody(
                        """{"code":"E_RATE","message":"too many pending pairing polls","retryable":true}""",
                    )
                    is ResolveStep.State -> json(
                        200,
                        buildJsonObject {
                            put("sessionId", "sid")
                            put("state", step.state)
                            put("name", "Studio")
                            put("platform", "windows")
                            put("publicKey", base64Url(pcPublicKey))
                            put("fingerprint", "00000000")
                            put("expiresAt", "2026-11-17T00:05:00Z")
                        },
                    )
                }
            }

            "/v1/pair/claim" -> {
                claimCount++
                claimBody = request.body.readUtf8()
                val wrap = KeyWrap.wrapForDevice(contentKey, pcPublicKey, phonePrivateKey)
                json(
                    201,
                    buildJsonObject {
                        put("deviceId", "d1")
                        put("householdId", "h1")
                        put("accessToken", "a1")
                        put("refreshToken", "r1")
                        put("expiresAt", "2026-11-17T00:15:00Z")
                        put("wrappedKey", base64Url(wrap))
                        put("voucherPublicKey", base64Url(phonePublicKey))
                    },
                )
            }

            else -> MockResponse().setResponseCode(404)
        }

        fun start() {
            server.dispatcher = this
            server.start()
        }

        fun close() = server.shutdown()

        private fun json(code: Int, body: JsonObject) =
            MockResponse().setResponseCode(code).setBody(body.toString())

        private fun base64Url(bytes: ByteArray): String =
            Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }
}
