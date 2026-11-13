package com.hopa.core.ports

interface VoicePort {
    suspend fun transcribe(wav: ByteArray): String

    suspend fun speak(text: String)
}
