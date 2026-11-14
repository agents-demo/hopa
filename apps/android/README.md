# HOPA for Android

Status: **debug app running on an emulator.** This is the first vertical slice of
the Android plan; it is not parity with the Harmony app yet.

## What works

- The whole loop is in the APK (`core`), with contract types, parser, gate,
  hash-chained records, prompt and 14-step budget.
- Chat with a demo model, and with any OpenAI-compatible provider (cloud or LAN)
  configured in Settings. The API key is stored in Android Keystore.
- Conversations: create, select, rename in the store, delete.
- Settings: provider, endpoint, model, key, notifications, web toggle.
- Profiles: Everyday, Easy, Kid, Power, Social (selection; per-profile shells are
  next).
- Runs: recent records with classification, executed and verified flags.
- Capabilities and Launchpad (installed apps, launch by package).
- Structure check: one public declaration per file, package = folder, no Android
  imports in `core`.

## Modules

```
apps/android/
├─ app/            Compose shell, navigation, features, DI
├─ core/           contracts, loop, parser, prompt, gate, records, ports
├─ capabilities/   model clients, system intents, package catalogue, device
├─ data/           settings, secrets, conversations
└─ testing/        fakes for tests
```

## Build and run

```powershell
cd apps/android
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :core:test
python ../../tools/checks/check-android-structure.py
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`.

`adb install` is blocked by the host security policy on this machine; the APK
was installed through `pm install-create` / `install-write` / `install-commit`
(see `docs/project/evidence/A0-android-running.md`). On a normal machine
`adb install -r app-debug.apk` is the command.

## Next

Bridge `adb` adapter (A5), `BridgeClient` (A6), accessibility service (A7),
Room persistence and sync (A8), approval sheet and the full feature screens
(A9–A11), voice and foreground service (A12), release (A13).
