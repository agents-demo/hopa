package com.hopa.sidecar

import java.util.Base64
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

import com.hopa.sidecar.backend.BackendSession
import com.hopa.sidecar.startup.pairBackendUrl
import com.hopa.sidecar.backend.backendContentKey

/** The pieces of the admission entry point that do not need a live backend. */
class MainArgsTest {
    @Test
    fun `pair backend recognizes only a real following url`() {
        assertEquals(
            "wss://example.test/v1/gateway",
            pairBackendUrl(arrayOf("--pair-backend", "wss://example.test/v1/gateway")),
        )
        assertNull(pairBackendUrl(emptyArray()))
        assertNull(pairBackendUrl(arrayOf("--pair-backend")))
        assertNull(pairBackendUrl(arrayOf("--pair-backend", "--other")))
        assertNull(pairBackendUrl(arrayOf("--pair-backend", "  ")))
    }

    @Test
    fun `a stored content key must be 32 bytes`() {
        val key = ByteArray(32) { it.toByte() }
        val valid = session(Base64.getEncoder().encodeToString(key))
        assertArrayEquals(key, backendContentKey(valid))

        assertNull(backendContentKey(session("not base64")))
        assertNull(backendContentKey(session(Base64.getEncoder().encodeToString(ByteArray(31)))))
    }

    private fun session(contentKeyBase64: String) = BackendSession(
        deviceId = "d1",
        householdId = "h1",
        accessToken = "a1",
        refreshToken = "r1",
        expiresAt = "2026-11-22T00:00:00Z",
        gatewayUrl = "wss://example.test/v1/gateway",
        contentKeyBase64 = contentKeyBase64,
        privateKeyBase64 = "",
    )
}
