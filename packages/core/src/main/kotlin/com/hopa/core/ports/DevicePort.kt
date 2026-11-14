package com.hopa.core.ports

import com.hopa.core.contracts.Observation

interface DevicePort {
    suspend fun observe(): Observation

    suspend fun tap(ref: String? = null, x: Int? = null, y: Int? = null)

    /** Two presses at the same point; the accessibility adapter dispatches both strokes. */
    suspend fun doubleTap(ref: String? = null, x: Int? = null, y: Int? = null) {
        tap(ref, x, y)
    }

    /** One press held; the accessibility adapter holds it, adb swipes in place. */
    suspend fun longPress(ref: String? = null, x: Int? = null, y: Int? = null) {
        tap(ref, x, y)
    }

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
