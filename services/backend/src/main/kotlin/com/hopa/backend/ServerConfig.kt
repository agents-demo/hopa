package com.hopa.backend

import com.hopa.backend.auth.AuthPort
import com.hopa.backend.pairing.PairingApi
import com.hopa.backend.pairing.TokenIssuer
import com.hopa.backend.store.DbProbe
import com.hopa.backend.tasks.DeviceDirectory

/**
 * Everything the application needs that comes from outside a test: the build
 * version, the auth port, the device directory and the database probe. Secrets
 * are read from the environment in [main], never defaulted here.
 */
data class ServerConfig(
    val version: String,
    val auth: AuthPort = AuthPort.DenyAll,
    val devices: DeviceDirectory = DeviceDirectory.Empty,
    val db: DbProbe = DbProbe.Unconfigured,
    val pairing: PairingApi? = null,
    val bootstrapToken: String? = null,
    val tokenIssuer: TokenIssuer? = null,
)
