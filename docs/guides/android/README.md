# HOPA on Android

Android runs the whole assistant: its own agent loop, its own model calls, its own
records. It is not a thin client (ADR-0016). It can act on the device in two ways
(ADR-0017):

1. **through the bridge (`adb`)**, the same shape as `hdc` on Harmony — works on a
   lab device or a phone with USB/Wi-Fi debugging;
2. **on-device `AccessibilityService`**, when the user grants it and no bridge is
   available.

Neither the loop nor the UI knows which one runs; both sit behind `DevicePort`.

## Prerequisites

| Tool | Version | Why |
|---|---|---|
| JDK | 17 | Gradle/AGP |
| Android SDK | API 34 platform + build-tools | compile and run |
| `adb` | platform-tools | device, screenshots, `uiautomator` |
| Gradle | via the wrapper in `apps/android` | no global install needed |

## Two execution paths

### Bridge (`adb`) — primary

The PC runs `hopa-bridge` with an Android adapter; the app points at it the way the
Harmony app points at the `hdc` bridge. This path gives the same features as
Harmony (launch, tap, type, swipe, screenshot, voice transcription on the PC) and
is what the evaluation suite exercises first.

- App side: `BridgeClient` (HTTP), target selection, pairing.
- Bridge side: `adb` transport, `uiautomator dump` parsing, `am start`, `input`,
  `screencap`; `platform: android` in `/health`.
- No accessibility permission needed.

### On-device accessibility — fallback

Works without a PC, after an explicit disclosure screen.

- `AccessibilityService` observes the window tree and performs clicks/gestures.
- The screen is captured through `takeScreenshot` (API 30+) or the media
  projection; the tree is the primary observation, as on Harmony.
- The user can revoke it at any time; the app then says it cannot act.

**Distribution note:** Google Play restricts `AccessibilityService` to apps whose
primary purpose is accessibility. Plan for sideload/enterprise first, or a Play
submission with the accessibility declaration; do not assume Play approval.

## Project shape

```
apps/android/
├─ app/                 # Compose UI, navigation, ViewModel
├─ core/                # loop, gate, records, prompt, contracts types
├─ capabilities/        # device adapters: adb bridge, accessibility, browser, system
├─ data/                # sessions, settings, key store (Keystore)
└─ androidTest/         # conformance + emulator tests
```

The loop mirrors `apps/harmony/core/agent`; the behaviour is defined by
`contracts/schemas` and `contracts/fixtures`, not by copying code.

## Permissions

| Permission | When |
|---|---|
| `INTERNET` | model and bridge |
| `BIND_ACCESSIBILITY_SERVICE` | on-device path only |
| `POST_NOTIFICATIONS` | "answer ready" notifications |
| `RECORD_AUDIO` | voice input |
| `FOREGROUND_SERVICE_*` | a run that must survive a screen-off |

No `QUERY_ALL_PACKAGES` unless the launcher needs it; use explicit package queries
for the catalogue.

## Signing and release

- Debug: default keystore.
- Release: a keystore kept out of git; `keystore.properties` is gitignored.
- The APK maps to `apps/android/app/build/outputs/apk/release/`.
- Versioning follows `docs/project/operations/versioning.md`.

## Network and the model (ADR-0019)

The app is not fully offline: the shell is, the model is not.

| Tier | What works | Requirement |
|---|---|---|
| Shell | history, settings, records, catalogue, launchpad, accessibility inspection, deterministic quick commands | none |
| LAN model | a full turn against an OpenAI-compatible server on the same network (Ollama, llama.cpp, vLLM), key optional | PC/server on the LAN; cleartext allowed only to private ranges |
| Cloud | a full turn with the configured provider | internet + key |

The client shows `cloud`, `LAN`, `shell only` or `no model`. A turn that needs a
model refuses before it starts; it never queues and claims to be offline. The
payment gate is local in every tier.

## Testing

- Unit tests per module.
- Conformance: run `contracts/fixtures/conformance.json` through the Kotlin loop.
- Emulator smoke: launch an app, tap, screenshot, one full turn with a stub model.
- Device smoke: the same on hardware, with both execution paths if available.

## Related

- [Android development plan](../../project/plan/android/README.md)
- [Android architecture](../../design/architecture/apps-android.md)
- [Platform capability matrix](../../reference/platform-matrix.md)
- [Adding a platform](../../../services/docs/guides/adding-a-platform.md)
- [Contracts](../../reference/contracts/observation.md)
