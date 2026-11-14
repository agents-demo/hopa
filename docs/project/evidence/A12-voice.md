# A12 - voice and the foreground run

Date: 2026-11-14. Host: Windows; `emulator-5554`, API 35.

## Dictation

- `VoiceRecorder` records from `AudioRecord` at 16 kHz, mono, PCM16 on a daemon
  thread; `stop()` returns null under 100 ms of audio and a WAV otherwise. It
  never throws at the caller.
- `WavFile` writes the 44-byte RIFF/WAVE/fmt/data header; the unit test checks
  every field.
- `BridgeClient.transcribe(wav)` posts base64 audio to `/transcribe`; the app
  builds it only with a bridge address and token, else the UI says "Connect the
  bridge to dictate".
- The composer mic starts/stops the recording; text lands in the composer and is
  not sent. RECORD_AUDIO is declared and requested; a denial is stated honestly.
- `ChatViewModel` carries `recording`, `transcribing`, `voiceError`; the composer
  shows `Listening…`, a spinner, and "I did not catch that".

Verified: tap mic → `Listening…` → `POST /transcribe` on the bridge → empty
result → "I did not catch that".

## Read aloud

- `Speaker`: the PC voice when a bridge is configured (`POST /speak` returns a
  WAV played with MediaPlayer from the cache), Android TTS otherwise; both are
  capped at 600 characters.
- Long-press on an assistant message offers **Read aloud**.

Not verified with audible output on the emulator; the client paths are built and
the bridge endpoints are covered by the HTTP tests.

## Foreground run

- `RunService` is declared with `foregroundServiceType="shortService"`;
  POST_NOTIFICATIONS is requested at first launch; the channel is `hopa_runs`.
- A turn starts the service before the loop and stops it in a `finally`; the
  notification (id 1001) has a Stop action that sets `cancelRequested`, which the
  loop checks before every model call and action.
- The loop is wrapped in `withTimeoutOrNull(120_000)`; a timeout appends
  "I stopped after two minutes." instead of a silent hang.

Verified: sending a task started `RunService`
(`isForeground=true foregroundId=1001 types=0x00000800`), the shade showed
"HOPA is working" plus STOP, and tapping STOP removed the service.

## Not done

- The denied-notification path and a test-notification action.
- A screen-off run on a real phone and a spoken-mic run.
- TTS voice/rate settings.
