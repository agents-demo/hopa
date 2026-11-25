package com.hopa.inference.local

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class LocalEndpointTest {
    @Test
    fun loopback_hosts_are_the_only_on_device_targets() {
        assertTrue(LocalEndpoint.isLoopback("http://127.0.0.1:8080/v1"))
        assertTrue(LocalEndpoint.isLoopback("http://localhost:1234/v1"))
        assertTrue(LocalEndpoint.isLoopback("http://[::1]:9000/v1"))
    }

    @Test
    fun a_lookalike_host_is_not_loopback() {
        assertFalse(LocalEndpoint.isLoopback("http://127.0.0.1.example.com/v1"))
        assertFalse(LocalEndpoint.isLoopback("https://127.0.0.1/v1"))
        assertFalse(LocalEndpoint.isLoopback("https://api.deepseek.com/v1"))
        assertFalse(LocalEndpoint.isLoopback(""))
    }
}
