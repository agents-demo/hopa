package com.hopa.backend.gateway

import com.hopa.backend.auth.DeviceIdentity
import kotlinx.coroutines.channels.Channel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceRegistryTest {
    private val identity = DeviceIdentity("dev-a", "hh-1", "mem-1")

    private fun session(): DeviceRegistry.Session =
        DeviceRegistry.Session(identity, Channel())

    @Test
    fun `a stale session cannot remove the session that replaced it`() {
        val registry = DeviceRegistry()
        val first = session()
        val second = session()
        registry.join(first)
        registry.join(second)

        registry.leave(first)

        assertTrue("the reconnect must still be online", registry.online("dev-a"))
        assertEquals(second, registry.sessionFor("dev-a"))
    }

    @Test
    fun `leaving the current session removes it`() {
        val registry = DeviceRegistry()
        val only = session()
        registry.join(only)

        registry.leave(only)

        assertTrue(!registry.online("dev-a"))
    }
}
