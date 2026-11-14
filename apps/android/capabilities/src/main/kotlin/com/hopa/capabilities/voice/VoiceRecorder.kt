package com.hopa.capabilities.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/** Records 16 kHz mono PCM16 and returns a WAV; never throws at the caller. */
class VoiceRecorder(
    private val context: Context,
) {
    @Volatile
    private var recording = false
    private var worker: Thread? = null
    private var buffer: ByteArrayOutputStream? = null
    private var audio: AudioRecord? = null

    val isRecording: Boolean
        get() = recording

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun start(): Boolean {
        if (recording || !hasPermission()) {
            return false
        }
        val sampleRate = 16_000
        val minimum = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minimum <= 0) {
            return false
        }
        val record = runCatching {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minimum * 2,
            )
        }.getOrNull() ?: return false
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return false
        }

        val pcm = ByteArrayOutputStream()
        buffer = pcm
        audio = record
        recording = true
        record.startRecording()
        worker = thread(name = "hopa-voice", isDaemon = true) {
            val chunk = ByteArray(minimum)
            while (recording) {
                val read = record.read(chunk, 0, chunk.size)
                if (read > 0) {
                    pcm.write(chunk, 0, read)
                }
            }
        }
        return true
    }

    /** Stops the recorder and returns WAV bytes, or null when nothing usable was captured. */
    fun stop(): ByteArray? {
        if (!recording) {
            return null
        }
        recording = false
        worker?.join(1_000)
        worker = null
        val record = audio
        audio = null
        runCatching { record?.stop() }
        record?.release()
        val pcm = buffer?.toByteArray() ?: return null
        buffer = null
        if (pcm.size < 1_600) {
            return null
        }
        return WavFile.wrap(pcm)
    }
}
