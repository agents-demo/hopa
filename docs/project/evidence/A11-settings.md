# A11 - Settings: character, self-check and about

Date: 2026-11-14.

## Character

- `AppSettings` gains `tone` (friendly/direct) and `chattiness`
  (short/balanced/detailed), persisted in DataStore.
- Settings shows two chip rows that save immediately; no separate Save.
- `ChatViewModel` adds `Character: <tone> tone, <chattiness> length.` to the
  memory block of `TurnContext`, so every prompt carries it.

## Self-check

- `SelfCheckScreen` shows: model label and provider, PC bridge (not configured /
  connected / unreachable / not checked) with the address, on-device
  accessibility (off / enabled not connected / enabled and connected), and the
  data counts (chats, records, facts, skills).
- `Run self-check` re-reads everything and calls `/health` when a bridge token
  exists; failures are values, not crashes.
- Reachable from Settings.

## About

- Version (from PackageManager), package name, a short honest paragraph about
  offline answers/device paths, and a Release notes link.
- Reachable from Settings.

## Verification

- `:app:testDebugUnitTest` and `:app:assembleDebug` are green; structure check 0.
- The UI path was not captured live: adb input on the emulator stopped
  registering taps after the Power-home test (the dump kept returning the Power
  screen), so the screenshots for this slice are missing. The code paths are
  covered by compilation and the existing tests.
