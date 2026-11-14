package com.hopa.core.testing

import com.hopa.core.ports.Clock

/** Deterministic time; records how long the loop waited. */
class FakeClock(
    private val now: Long = 1_700_000_000_000,
) : Clock {
    var slept = 0L

    override fun nowMillis(): Long = now

    override suspend fun sleep(millis: Long) {
        slept += millis
    }
}
