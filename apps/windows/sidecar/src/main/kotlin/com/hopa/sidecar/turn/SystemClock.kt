package com.hopa.sidecar.turn

import com.hopa.contracts.ports.Clock

class SystemClock : Clock {
    override fun nowMillis(): Long = System.currentTimeMillis()

    override suspend fun sleep(millis: Long) {
        kotlinx.coroutines.delay(millis)
    }
}
