package com.hopa.core.ports

import com.hopa.core.contracts.Observation

interface DevicePort {
    suspend fun observe(): Observation

    suspend fun tap(ref: String? = null, x: Int? = null, y: Int? = null)

    suspend fun type(text: String, ref: String? = null)

    suspend fun swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, velocity: Int = 600)

    suspend fun pressBack()

    suspend fun pressHome()

    suspend fun launch(packageName: String)

    suspend fun stop(packageName: String)

    suspend fun foreground(): String

    suspend fun screenshot(): ByteArray?

    suspend fun apps(): List<InstalledApp>
}
