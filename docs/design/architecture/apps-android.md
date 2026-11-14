# The Android app

Status: designed, not built. This page is the architecture the Android plan
implements: the loop runs **in the app** (ADR-0016), execution has two paths
(ADR-0017), and the full phase plan is `docs/project/plan/android/`.

## Modules

```
apps/android/
├─ app/            Compose UI, navigation, ViewModel, state holders
├─ core/           loop, prompt, decision parsing, gate, records, budgets
├─ capabilities/   DevicePort adapters, browser, system intents, model client
├─ data/           sessions and settings (Room/DataStore), Keystore
└─ androidTest/    conformance runner, emulator and device tests
```

Dependency direction mirrors Harmony: `app → capabilities → core`; `core` has no
Android imports, so it is unit-testable on the JVM and reusable on Windows if
that client is Kotlin.

## The loop

| Harmony (ArkTS) | Android (Kotlin) |
|---|---|
| `core/agent/AgentLoop.ets` | `core/loop/AgentLoop.kt` |
| `core/gate/ApprovalPolicy.ets` | `core/gate/ApprovalPolicy.kt` |
| `core/gate/ActionExecutor.ets` | `core/gate/ActionExecutor.kt` |
| `core/runs/RunRecord.ets`, `RunStore` | `core/runs/RunRecord.kt`, `RunStore.kt` |
| `core/model/ModelClient.ets` | `core/model/ModelClient.kt` |
| `capabilities/llm/OpenAiClient.ets` | `capabilities/llm/OpenAiClient.kt` |
| `capabilities/accessibility/*` | `capabilities/device/{Adb,Accessibility}Device.kt` |
| `app/services/ConversationService.ets` | `data/sessions/ConversationStore.kt` |
| `app/services/BridgeClient.ets` | `capabilities/bridge/BridgeClient.kt` |
| `app/services/ChatSync.ets` | `data/sessions/ChatSync.kt` |

The Kotlin loop is not a translation for its own sake: it consumes
`contracts/schemas` and must pass `contracts/fixtures`.

## Execution: two adapters, one seam

```
        AgentLoop → ActionExecutor → DevicePort
                                     ├─ AdbDevice          (via hopa-bridge, adb)
                                     └─ AccessibilityDevice (on-device service)
```

- **`AdbDevice`** talks to `services/bridge`, which gains an `adb` transport and
  the `android` platform. This is the primary path: it gives the features the
  Harmony bridge already has (launch, tap, type, swipe, screenshot, foreground,
  transcribe/speak on the PC).
- **`AccessibilityDevice`** observes the accessibility tree and dispatches
  gestures locally. Screen pixels come from `AccessibilityService.takeScreenshot`
  (API 30+) or a media-projection fallback.
- Selection is a user setting with an honest status line: `bridge`, `on-device`,
  or `cannot act`.

Both adapters implement the same methods the bridge exposes today: `observe`,
`tap`, `type`, `swipe`, `screenshot`, `launch`, `stop`, `foreground`, `apps`,
plus `serial` and `platform`.

## Model and keys

- OpenAI-compatible client, same request shape as Harmony (`max_tokens`,
  `reasoning_effort: low`).
- The key lives in Android Keystore; the settings screen never prints it.
- Provider, endpoint and model are settings, not build constants.

## Data

- Sessions, turns and run records in Room; the same JSON shapes as the app store
  so a bridge sync can merge them.
- Tombstones for deletion, drafts protected across merges (same rules as the
  Harmony sync).
- Screenshots and step frames are files, not blobs in the database.

## Sync

Optional and bridge-mediated, exactly like the laptop:

- push/pull sessions with `rev` and tombstones;
- a client that never syncs is a first-class offline client.

## Voice

Record locally, send WAV to `/transcribe` on the bridge; fall back to
`SpeechRecognizer` when no bridge is configured. Dictation fills the box and never
sends (the same rule as the laptop composer).

## Testing and evaluation

- Conformance fixtures run on the JVM (no device).
- Emulator suite: one turn with a stub model, both adapters where possible.
- `services/evals` gains `platform` and `bundle` mapping; an Android task points
  at the Android build and either the adb bridge or on-device accessibility.

## What is explicitly not here

- No agent loop on a server for this client; no account required.
- No Play-only assumptions; the accessibility path has a distribution caveat.
- No copy of ArkTS code: behaviour is shared through fixtures, not files.
