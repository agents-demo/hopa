# Platform capability matrix

What each client can do, and through which mechanism. "Planned" means the
implementation is on the roadmap, not that it exists.

| Capability | HarmonyOS (today) | Android via bridge (planned) | Android on-device (planned) | Windows (planned) |
|---|---|---|---|---|
| Observe screen as text nodes | Accessibility capability | `uiautomator dump` over adb | `AccessibilityService` tree | UI Automation tree |
| Screen pixels | `snapshot_display` | `screencap` | `takeScreenshot` (API 30+) | `PrintWindow`/DXGI |
| Tap / long press | Accessibility | `input tap`, `swipe` | gesture dispatch | UIA invoke / SendInput |
| Type text | Accessibility | `input text` (ASCII caveat) | `ACTION_SET_TEXT` / IME | UIA ValuePattern / SendInput |
| Swipe / scroll | Accessibility | `input swipe` | gesture dispatch | UIA ScrollPattern |
| Launch / stop app | Want + `aa` | `am start` / `am force-stop` | `Intent` / `am` via shell | `Process.Start` / UIA |
| Foreground app | Accessibility | `dumpsys window` | accessibility event | UIA focus |
| Installed apps | bundle manager | `pm list packages` | `PackageManager` | registry / Start menu |
| Model calls | on device | on device | on device | on device |
| Voice in (transcribe) | bridge `/transcribe` | bridge `/transcribe` | `SpeechRecognizer` fallback | bridge or local |
| Voice out (speak) | bridge `/speak` | bridge `/speak` | Android TTS | Windows SAPI |
| Browser automation | ArkWeb pane | none (bridge has no browser) | WebView + JS bridge | WebView2 |
| System intents (alarm, share, call) | system capability | via app or adb | `Intent` | shell / COM |
| Sandbox scripts | Pyodide/QuickJS | local | local (WebView JS) | local (JScript/QuickJS) |
| Chat sync | bridge `/chats` | bridge `/chats` | bridge `/chats` | bridge `/chats` |
| Run survives backgrounding | background task + topmost window | n/a (runs on PC) | foreground service + FGS type | n/a (desktop) |
| Run record chain | `RunRecord` hash chain | same contract | same contract | same contract |
| Conformance fixtures | must pass | must pass | must pass | must pass |

## Rules

- A capability is "supported" only when the device smoke for it exists and the
  conformance fixtures pass on that client.
- A platform may implement a capability differently; it may not change the
  contract (`contracts/schemas`, `contracts/fixtures`).
- If a platform cannot support a capability, the UI says so on the capability
  page; it does not silently fail.
- The Android bridge path is the reference for Android: it is the one the
  evaluation suite drives first, because it needs no user permission.
