package com.hopa.capabilities.voice

import android.content.Context
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import java.io.File
import java.util.Locale

/** Speaks a reply: the PC's WAV when available, Android TTS otherwise. */
class Speaker(
    context: Context,
) {
    private val app = context.applicationContext
    private var tts: TextToSpeech? = null
    private var ready = false
    private var player: MediaPlayer? = null

    init {
        tts = TextToSpeech(app) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                tts?.language = Locale.getDefault()
            }
        }
    }

    fun speak(text: String): Boolean {
        val trimmed = text.trim().take(600)
        if (trimmed.isEmpty() || !ready) {
            return false
        }
        tts?.speak(trimmed, TextToSpeech.QUEUE_FLUSH, null, "hopa-reply")
        return true
    }

    fun play(wav: ByteArray): Boolean {
        stop()
        val file = File(app.cacheDir, "hopa-speak.wav")
        return runCatching {
            file.writeBytes(wav)
            player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener { completed ->
                    completed.release()
                    if (player === completed) {
                        player = null
                    }
                    file.delete()
                }
                prepare()
                start()
            }
            true
        }.getOrDefault(false)
    }

    fun stop() {
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        tts?.stop()
    }
}
