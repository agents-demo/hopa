package com.hopa.capabilities.voice

import java.io.ByteArrayOutputStream

/** A 16 kHz mono PCM16 WAV, the shape the bridge's `/transcribe` expects. */
object WavFile {
    private const val HEADER_BYTES = 44

    fun wrap(pcm: ByteArray, sampleRate: Int = 16_000, channels: Int = 1): ByteArray {
        val bits = 16
        val byteRate = sampleRate * channels * bits / 8
        val blockAlign = channels * bits / 8
        val output = ByteArrayOutputStream(HEADER_BYTES + pcm.size)
        output.write("RIFF".toByteArray(Charsets.US_ASCII))
        output.write(le32(36 + pcm.size))
        output.write("WAVE".toByteArray(Charsets.US_ASCII))
        output.write("fmt ".toByteArray(Charsets.US_ASCII))
        output.write(le32(16))
        output.write(le16(1))
        output.write(le16(channels))
        output.write(le32(sampleRate))
        output.write(le32(byteRate))
        output.write(le16(blockAlign))
        output.write(le16(bits))
        output.write("data".toByteArray(Charsets.US_ASCII))
        output.write(le32(pcm.size))
        output.write(pcm)
        return output.toByteArray()
    }

    private fun le16(value: Int): ByteArray = byteArrayOf(
        (value and 0xFF).toByte(),
        ((value shr 8) and 0xFF).toByte(),
    )

    private fun le32(value: Int): ByteArray = byteArrayOf(
        (value and 0xFF).toByte(),
        ((value shr 8) and 0xFF).toByte(),
        ((value shr 16) and 0xFF).toByte(),
        ((value shr 24) and 0xFF).toByte(),
    )
}
