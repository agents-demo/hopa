package com.hopa.app.navigation

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class LaunchModeTest {
    @Test
    fun `no url and no identity is local only with the pairing entry hidden`() {
        val decision = LaunchMode.decide(configuredUrl = null, storedUrl = "", storedDeviceId = "", reachable = false)

        assertEquals(LaunchMode.LocalOnly, decision.mode)
        assertEquals(false, decision.showGatewayPairing)
        assertNull(decision.banner)
    }

    @Test
    fun `configured but unreachable without an identity stays quiet`() {
        val decision = LaunchMode.decide(
            configuredUrl = "https://gateway.example",
            storedUrl = "",
            storedDeviceId = "",
            reachable = false,
        )

        assertEquals(LaunchMode.LocalOnlyUnreachable, decision.mode)
        assertNull(decision.banner)
        assertEquals(true, decision.showGatewayPairing)
    }

    @Test
    fun `configured reachable and no identity asks to sign in`() {
        val decision = LaunchMode.decide(
            configuredUrl = "https://gateway.example",
            storedUrl = "",
            storedDeviceId = "",
            reachable = true,
        )

        assertEquals(LaunchMode.SignIn, decision.mode)
        assertEquals(true, decision.showGatewayPairing)
    }

    @Test
    fun `skipping the account wins over a reachable gateway`() {
        val decision = LaunchMode.decide(
            configuredUrl = "https://gateway.example",
            storedUrl = "",
            storedDeviceId = "",
            reachable = true,
            skipped = true,
        )

        assertEquals(LaunchMode.LocalOnly, decision.mode)
        assertNull(decision.banner)
        assertEquals(false, decision.showGatewayPairing)
    }

    @Test
    fun `a stored identity is paired`() {
        val decision = LaunchMode.decide(
            configuredUrl = null,
            storedUrl = "wss://gateway.example/v1/gateway",
            storedDeviceId = "device-1",
            reachable = true,
        )

        assertEquals(LaunchMode.Paired, decision.mode)
        assertEquals(true, decision.showGatewayPairing)
    }

    @Test
    fun `a stored url that is unreachable without an identity stays quiet`() {
        val decision = LaunchMode.decide(
            configuredUrl = null,
            storedUrl = "https://gateway.example",
            storedDeviceId = "",
            reachable = false,
        )

        assertEquals(LaunchMode.LocalOnlyUnreachable, decision.mode)
        assertNull(decision.banner)
    }

    @Test
    fun `a paired phone gets a plain note when the account is unreachable`() {
        val decision = LaunchMode.decide(
            configuredUrl = null,
            storedUrl = "https://gateway.example",
            storedDeviceId = "device-1",
            reachable = false,
        )

        assertEquals(LaunchMode.LocalOnlyUnreachable, decision.mode)
        assertEquals("HOPA still works on this phone.", decision.banner)
    }
}
