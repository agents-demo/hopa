package com.hopa.sidecar.backend

import java.nio.file.Files
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class BackendSessionStoreTest {
    private fun session() = BackendSession(
        deviceId = "d1",
        householdId = "h1",
        accessToken = "access-token-value",
        refreshToken = "refresh-token-value",
        expiresAt = "2026-11-17T00:15:00Z",
        gatewayUrl = "wss://example.test/v1/gateway",
        contentKeyBase64 = "Y29udGVudC1rZXk",
        privateKeyBase64 = "cHJpdmF0ZS1rZXk",
    )

    @Test
    fun `a session survives a reload`() {
        val directory = Files.createTempDirectory("hopa-backend-session")
        val path = directory.resolve("backend-session.json")
        val store = BackendSessionStore(path)

        store.save(session())

        assertEquals(session(), BackendSessionStore(path).load())
        assertTrue(Files.exists(path))
    }

    @Test
    fun `the file is json and toString redacts secrets`() {
        val directory = Files.createTempDirectory("hopa-backend-session-redacted")
        val path = directory.resolve("backend-session.json")
        BackendSessionStore(path).save(session())

        val text = Files.readString(path)
        assertTrue(text.contains("\"deviceId\""))
        assertTrue(text.contains("\"contentKeyBase64\""))
        // The file itself must hold the tokens, or the sidecar cannot reconnect.
        assertTrue(text.contains("access-token-value"))

        val printed = session().toString()
        assertFalse(printed.contains("access-token-value"))
        assertFalse(printed.contains("refresh-token-value"))
        assertFalse(printed.contains("Y29udGVudC1rZXk"))
        assertTrue(printed.contains("d1"))
    }
}
