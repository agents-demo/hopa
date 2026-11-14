# A7 - accessibility: disclosure, kill switch and gestures

Date: 2026-11-14. Host: Windows; `emulator-5554`, API 35.

## What changed

- **Disclosure screen** (`Phone access`): what is read, what is dropped and
  redacted, that screenshots happen only during a run at most once a second, and
  that a screen which hides itself stays hidden. Reachable from Settings.
- **Kill switch**: `accessibilityAllowed` in settings. When off, the chat picks
  `UnavailableDevicePort` instead of the accessibility device, so every action
  is refused even if Android still has the service enabled. The disclosure
  screen shows `Android service: enabled/off` and `Connection: live/not connected`
  by polling every 1.5 s.
- **Fail closed**: `AccessibilityDevice.service()` now checks
  `AccessibilityState.isEnabled(context)` before every observe/act and throws
  `accessibility is disabled in Android settings`, then `accessibility is enabled
  but not connected yet`. No action runs on a stale binding.
- **Gestures**: `DevicePort.doubleTap` and `longPress`; the accessibility adapter
  dispatches two strokes 120 ms apart / one 700 ms stroke; adb double-taps and
  swipes in place; the executor routes `ui.doubleTap` and `ui.longPress` to the
  new methods instead of a plain tap.
- **Screenshot policy**: at most one capture per second, `null` on a failed or
  secure window, and the call is wrapped so a `SecurityException` is an honest
  "no frame", never a crash.
- **Observation**: `NodeTreeReader` now numbers the root `e1` and children from
  `e2`, and `AccessibilityDevice` passes the tree through `ObservationProducer`
  (pre-order refs, password fields dropped, redaction, caps, hash).

## Verified on the emulator

```
adb shell settings put secure enabled_accessibility_services \
  com.hopa.android/com.hopa.capabilities.accessibility.HopaAccessibilityService
adb shell settings put secure accessibility_enabled 1
```

`dumpsys accessibility` lists `Service[label=HOPA device control, ...]`, and the
Phone access screen shows **Android service: enabled** and **Connection: live**.
This is the first time the live instance was observed; the earlier failure was
before the disclosure screen existed.

`./gradlew :core:test :capabilities:testDebugUnitTest :app:assembleDebug` is
green; `ActionExecutorTest` now proves `ui.doubleTap` and `ui.longPress` reach
their own gestures and not `tap`.

## Typing (done in the plan-reconciliation pass)

`AccessibilityDevice.type` focuses the node, sends `ACTION_SET_TEXT`, falls back
to the clipboard plus `ACTION_PASTE`, and refuses with "the field refused the
text" instead of pretending. Non-ASCII works through the same path.

## Not done

- A full action turn through accessibility on the emulator was not captured: the
  scripted taps that were meant to disable the bridge and resend the demo raced
  with the keyboard, so the turn never started. The service binding itself is
  proven above.
- No real-phone run (the A7 gate needs one), no observation equality test against
  the bridge for one fixture screen, and no unit test for the gate/gesture
  mapping beyond the executor case.
- Background capture policy is described in the disclosure but the service does
  not restrict capture by run state yet.
