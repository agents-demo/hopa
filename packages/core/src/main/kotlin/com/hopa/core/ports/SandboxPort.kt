package com.hopa.core.ports

interface SandboxPort {
    suspend fun run(script: String): String
}
