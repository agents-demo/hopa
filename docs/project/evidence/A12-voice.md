# A12 - voice (dictation)

Date: 2026-11-14. Host: Windows; `emulator-5554`, API 35.

## Done

- `VoiceRecorder` records from `AudioRecord` at 16 kHz, mono, PCM16 on a daemon
  thread; `stop()` returns null for anything shorter than 100 ms of audio and a
  WAV otherwise. It never throws at the caller.
- `WavFile` writes the 44-byte RIFF/WAVE/fmt/data header; the unit test checks
  every field.
- `BridgeClient.transcribe(wav)` posts base64 audio to `/transcribe` and returns
  the text. The app builds that client only when a bridge address and token
  exist; otherwise the UI says "Connect the bridge to dictate".
- The composer mic starts and stops the recording. The text, when there is any,
  lands in the composer and is **not** sent: dictation fills only.
- RECORD_AUDIO is declared and requested at the first tap; a denial shows an
  honest message.
- `ChatViewModel` carries `recording`, `transcribing` and `voiceError`; the
  composer shows `Listening…`, a spinner while transcribing, and "I did not
  catch that" when the bridge returns nothing.

## Verified on the emulator

1. Tap the mic → `Listening…` (the permission was granted with `pm grant` for
   this run).
2. Tap stop → the bridge logged `POST /transcribe`.
3. The bridge returned an empty string (the emulator has no speech input) and
   the app showed `I did not catch that`; nothing was sent.

`WavFileTest` and a MockWebServer `transcribe` case are green; the Android job
runs both.

## Not done

- A spoken-text run on a phone with a real microphone.
- `/speak` playback and the on-device TTS fallback (600-char cap).
- Foreground service, ongoing notification, notification-permission denied path,
  120 s bound.
