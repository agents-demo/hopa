package com.hopa.core.ports

interface Clock {
    fun nowMillis(): Long

    suspend fun sleep(millis: Long)
}
