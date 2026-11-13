# ADR-0017 - Android acts through the bridge (adb) and, when possible, on-device

- Status: accepted
- Date: 2026-11-13

## Context

The HarmonyOS app executes actions through `capabilities/accessibility` on the
device, and the laptop drives it through the bridge (`hdc` + `uitest`). Android has
the same two possibilities:

1. **A PC bridge speaking `adb`** — the same shape as `hdc`: `uiautomator dump`,
   `input tap`, `am start`, `screencap`. It works for emulators, lab devices and
   users who keep the phone on USB/Wi-Fi debugging.
2. **On-device `AccessibilityService`** — no PC, but a permission the store
   restricts, and a service the system may kill.

The owner wants both, to show both to colleagues.

## Decision

- **Both adapters exist behind one seam** (`DevicePort`, already used by the
  bridge). Neither the loop nor the UI knows which one runs.
- **Priority**: when a bridge is configured and reachable, the client uses
  `AdbDevice` (bridge/adb). Otherwise it uses `AccessibilityDevice` if the user
  granted accessibility. If neither is available, the app still chats and plans,
  but says plainly that it cannot act on the device.
- **The bridge gains an Android backend**: `adb` transport, `uiautomator` layout
  parsing, `am start`/`input`/`screencap`, plus an `android` platform in the
  registry (`/health` reports it). This mirrors `hdc` and is a prerequisite for
  the APK's primary path.
- **On-device accessibility is a separate capability** with its own disclosure,
  settings screen and kill switch. It is not the default and is never enabled
  silently.
- **Distribution**: sideload / internal first. Google Play restricts
  `AccessibilityService` to apps whose primary purpose is accessibility; the
  on-device path must be declared and justified, or shipped only outside Play.

## Consequences

- Two code paths for every action; both must pass the same conformance fixtures
  and the same device smoke (one launch, one tap, one screenshot).
- The APK contains `BridgeClient` (HTTP, like the Harmony app) and a
  `DevicePort` implementation per path.
- The bridge's Android adapter is useful on its own: a Windows/laptop HOPA can
  drive an Android phone exactly as it drives a Harmony one today.
- The manifest carries `BIND_ACCESSIBILITY_SERVICE`, a disclosure screen and a
  foreground-service declaration where needed; Play submission needs a policy
  answer before release.

## Alternatives considered

- **Accessibility only.** Rejected: Play risk and no way to drive a lab device
  without user interaction.
- **adb only.** Rejected: the phone would be useless without a PC, which defeats
  an APK that runs the loop itself.
- **Root/ADB shell on device.** Rejected: not shippable to normal users.
