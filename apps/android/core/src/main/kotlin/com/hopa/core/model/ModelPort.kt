package com.hopa.core.model

interface ModelPort {
    suspend fun complete(request: ModelRequest): ModelReply
}
