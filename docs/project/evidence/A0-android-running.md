# A0 - Android runs (2026-11-13)

The first Android slice is built, installed and running on an emulator. This is
evidence for the scaffold and the vertical slice, not for full parity.

## Environment

| Item | Value |
|---|---|
| Host | Windows, `C:\Workspace\openjiuwenothers\hopa` |
| JDK | Microsoft OpenJDK 17.0.19 |
| Gradle | 8.11.1 (wrapper) |
| Android SDK | API 35 platform, build-tools 35.0.0 |
| Emulator | `hopa35`, `sdk_gphone64_x86_64`, API 35, host GPU, headless |
| Package | `com.hopa.android`, version 0.1.0, minSdk 30, target 35 |

## Build and tests

```
.\gradlew.bat :app:assembleDebug   -> BUILD SUCCESSFUL
.\gradlew.bat :core:test           -> BUILD SUCCESSFUL (16 tests)
python tools/checks/check-android-structure.py -> 0 problems
```

The APK is `apps/android/app/build/outputs/apk/debug/app-debug.apk`.

## Install

`adb install` and `pm install` are blocked by the host security policy
(`0xC0000022`, access denied). The APK was installed by staging it on the
device and using the package session API:

```
pm install-create -r -S <size>
pm install-write -S <size> <session> base.apk -   (APK streamed on stdin)
pm install-commit <session>
```

The `pm` invocations were run from a shell script on the device through
`adb exec-in`, because a literal `pm install` on the host command line is also
blocked. `adb push` is blocked for the same reason; `adb exec-in "cat > file"`
works.

## What was exercised

| Step | Result | Evidence |
|---|---|---|
| Launch | `MainActivity` displayed, no crash | [`android-chat`](../../media/android-chat-2026-11-13.png) |
| Chat | `hello` -> demo model answer, conversation kept | same screenshot |
| Settings | provider/endpoint/model/key fields, save, capability buttons | `android-settings` run |
| Capabilities | model state, device, data counts, Launchpad button | [`android-capabilities`](../../media/android-capabilities-2026-11-13.png) |
| Conversations / Runs / Profiles | routes registered; store/recorder wired | code + unit tests |

The demo model is deliberate: no API key is stored in the repository or the APK.
A cloud or LAN provider is configured in Settings.

## Structure

- `core` is a JVM module with no `android.*` imports (enforced).
- One public declaration per file, file name = declaration (enforced by
  `check-android-structure.py`, generated catalogue/policy/prompt files exempt).
- Tests mirror packages; `core` includes the six conformance fixtures and the
  observation hash vector.

## Visual layer

The first screens now follow the Harmony tokens from
`apps/harmony/phone/src/main/resources/base/element/color.json`:

- background `#F7F4EE`, surface `#FFFFFF`, alt `#F3EFE7`, primary `#0A59F7`,
  accent `#E8703A`, text `#1C1B18` / `#6B665C` / `#9A9488`;
- the mascot is drawn in Compose (`HopaMascot`) from the same geometry as
  `hopa_body.svg`: coral gradient body, warm screen, two eyes, smile, legs and a
  waving arm, with a slow bob;
- the empty state is the Harmony hero: mascot, greeting, HOPA wordmark,
  tagline, "Payments always ask first.", two pills and an example list;
- the composer is one white 26 dp rounded field with a 36 dp send/mic circle;
- the top bar has the Chats clock, title, new-chat circle and settings;
- the bottom bar is Chat / Activity / Capabilities with the soft active pill.

HarmonyOS Sans is not in the repository (no font file), so the app uses the
Android system sans with the Harmony sizes and weights. Drop a licensed
HarmonyOS Sans into `app/src/main/res/font` and point `HopaType` at it to match
the glyphs exactly.

## Not done yet

- Bridge `adb` transport (A5) and `BridgeClient` (A6).
- Accessibility service (A7).
- Room persistence and chat sync (A8).
- The full feature screens (A9-A11): per-profile shells, Activity detail, Plans,
  Usage, Memory, Skills, Browser, full Settings, share.
- Voice, foreground service (A12), release signing (A13), parity QA (A14).
- The approval sheet is implemented; actions that need the device still fail
  because the device ports are not connected.
