# Accessibility (a11y)

Status: **declared, installed and visible to the accessibility framework; the
Pura 90 emulator image has no UI to enable it.**

What was verified on 2026-11-06:

- the extension is declared in `apps/harmony/entry/src/main/module.json5`;
- the debug profile carries the ACL entry, and `atm dump -t -b com.hopa.agent`
  reports `grantStatus: 0` (granted) for
  `ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY`;
- `accessibility.getAccessibilityExtensionList('all', 'install')` inside HOPA
  lists `com.hopa.harness/agent/HopaAccessibilityExtension`;
- the emulator's Settings → Accessibility has **no** "Downloaded services" /
  "Installed services" page. Its "Advanced visual aids → More" contains only
  "Transition animations". So the user cannot enable the service on this image.

On a retail HarmonyOS device the services page may exist; the AppGallery ACL
approval is still required there because retail builds trust Huawei-issued
profiles, not the OpenHarmony test CA.

## What exists

- `AccessibilityBridge` — attaches to `AccessibilityExtensionContext`, captures the
  window root, and converts it into the core `Screen` / `ScreenNode` model.
- `HopaAccessibilityExtension` — `onConnect` / `onDisconnect` attach and detach
  the bridge.
- `AccessibilityCapability` — handles `a11y.observe` by capturing a screen; returns a
  typed failure when unavailable.
- `UiActionCapability` — handles `ui.tap` and `ui.longPress` with
  `performAction`, `ui.type` with `performAction('setText')`, `ui.doubleTap`
  as two clicks, `ui.swipe` and `ui.scroll` with `injectGesture`, `ui.back` and
  `ui.home` as edge/bottom gestures, and `ui.launch` through the entry app's
  `startAbility` when no PC bridge is preferred. Every other call returns a
  typed failure until the bridge is attached.

The app side of on-device control is therefore code-complete:
`ui.launch`, `ui.tap`, `ui.doubleTap`, `ui.type`, `ui.swipe`, `ui.scroll`,
`ui.longPress`, `ui.back`, `ui.home`, plus screen capture and the payment gate.
The only missing step on the emulator is enabling the service in Settings.

### Backend selection

`AccessibilityBridge.setRemotePreferred(true)` is set when a PC bridge is configured.
In that state the on-device capability declines every action, including
`ui.launch`; the bridge owns the actions (and can start an app while HOPA is in
the background). This matters because the service can report `connected` even
when the user has not enabled it, and capture in that state can hang; the local
capture is also raced against a 4 s guard.

What the bridge reads from each node:

| Field | Read |
|---|---|
| text / accessibilityText | yes |
| componentType | yes |
| bounds (rect) | yes |
| clickable | yes |
| checked | yes |
| children | yes |
| id | no (not exposed in `ElementAttributeValues`) |
| enabled | no (defaults to true) |

## What does not work yet

- The extension cannot be enabled on the emulator: Settings has no third-party
  services page.
- No AppGallery ACL approval, so retail devices are not covered.
- `ui.back` and `ui.home` are not implemented.
- Capture is pull-based; accessibility events do not trigger it.
- No OCR, vision, throttle, stale-ref invalidation or gesture-conflict policy.
- No hypium test yet: the bridge cannot attach without the service enabled.
- The API calls are marked deprecated in API 24; they compile, but the API 26
  signatures must be re-checked.

## How to enable it

1. File the accessibility ACL request for
   `ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY` using
   [docs/operations/acl-request.md](../operations/acl-request.md).
2. After approval, add the permission to `requestPermissions` and the ACL to the
   debug/release profile, then declare the extension in
   `apps/harmony/capabilities/accessibility/src/main/module.json5`:

   ```json5
   {
     "module": {
       "name": "capability_a11y",
       "type": "har",
       "extensionAbilities": [
         {
           "name": "HopaAccessibilityExtension",
           "srcEntry": "./ets/extension/AccessibilityExtension.ets",
           "type": "accessibility",
           "exported": false,
           "metadata": [
             { "name": "ohos.accessibleability", "resource": "$profile:accessibility_config" }
           ]
         }
       ]
     }
   }
   ```

3. Install the signed HAP.
4. Enable **HOPA** in `Settings → Accessibility`.
5. Verify `onConnect` runs and `AccessibilityCapability.isAvailable()` returns true.

Do not claim the capability works before all five steps are verified.

## Files

- `apps/harmony/capabilities/accessibility/src/main/ets/AccessibilityBridge.ets`
- `apps/harmony/capabilities/accessibility/src/main/ets/extension/AccessibilityExtension.ets`
- `apps/harmony/capabilities/accessibility/src/main/ets/AccessibilityCapability.ets`
- `apps/harmony/capabilities/accessibility/src/main/ets/UiActionCapability.ets`
- `apps/harmony/core/src/main/ets/Screen.ets`

## Tests

The HAP build compiles these files. There is no hypium test yet because the
extension cannot be connected without the ACL.

## Next

1. File the ACL and declare the extension.
2. Add a foreground-only guard and a live status indicator.
3. Add stale-ref invalidation.
4. Add OCR fallback for custom-drawn UIs.
5. Re-verify every signature against the API 26 SDK.
