package com.hopa.backend

import com.hopa.backend.auth.AuthPort
import com.hopa.backend.tasks.DeviceDirectory

/**
 * Everything the application needs that comes from outside a test: the build
 * version and, from Task 5 on, the auth port. Secrets are read from the
 * environment in [main], never defaulted here.
 */
data class ServerConfig(
    val version: String,
    val auth: AuthPort = AuthPort.DenyAll,
    val devices: DeviceDirectory = DeviceDirectory.Empty,
)
