package com.hopa.capabilities.voice

import org.junit.Assert.assertEquals
import org.junit.Test

class WavFileTest {
    @Test
    fun the_header_is_a_16khz_mono_pcm16_wav() {
        val pcm = ByteArray(1_600) { 1 }
        val wav = WavFile.wrap(pcm)

        assertEquals(44 + pcm.size, wav.size)
        assertEquals("RIFF", String(wav, 0, 4, Charsets.US_ASCII))
        assertEquals("WAVE", String(wav, 8, 4, Charsets.US_ASCII))
        assertEquals("fmt ", String(wav, 12, 4, Charsets.US_ASCII))
        assertEquals("data", String(wav, 36, 4, Charsets.US_ASCII))
        assertEquals(1, le16(wav, 20)) // PCM
        assertEquals(1, le16(wav, 22)) // mono
        assertEquals(16_000, le32(wav, 24))
        assertEquals(16, le16(wav, 34))
        assertEquals(pcm.size, le32(wav, 40))
    }

    private fun le16(bytes: ByteArray, at: Int): Int =
        (bytes[at].toInt() and 0xFF) or ((bytes[at + 1].toInt() and 0xFF) shl 8)

    private fun le32(bytes: ByteArray, at: Int): Int =
        (bytes[at].toInt() and 0xFF) or
            ((bytes[at + 1].toInt() and 0xFF) shl 8) or
            ((bytes[at + 2].toInt() and 0xFF) shl 16) or
            ((bytes[at + 3].toInt() and 0xFF) shl 24)
}
