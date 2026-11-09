# Accessibility ACL request (HOPA)

HOPA needs one restricted permission on a real Huawei phone:

```text
ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY
```

Without it, the app can launch other apps but cannot read or tap their screens.
The PC bridge is the fallback; this ACL is the standalone path.

## Before you request

- A Huawei developer account (AppGallery Connect). An individual account can
  file the request; approval is not guaranteed.
- The app registered in AGC with bundle name `com.hopa.agent`.
- The permission is declared in `module.json5` (already in this repository).
  Give it a user-facing reason. Huawei reviews the reason.

## Where to request

AppGallery Connect → **Development and services → ACL permissions**.

Accept the privacy notes, select
`ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY`, and fill in both fields.

## Usage scenario (copy this)

HOPA is a user-invoked phone agent. When the user asks it to operate an
installed app - for example "open Weibo and read the latest post" or "send
Alice the message I dictated" - HOPA's AccessibilityExtensionAbility reads the
accessibility tree of the currently visible screen and performs a tap, type,
swipe or back action for that request. It acts only on the foreground screen,
only after the user's explicit instruction, and every action is shown in the
in-app Activity record. Public actions (posting, sending, following) and every
payment require a separate confirmation before execution. HOPA does not run a
background screen monitor, does not collect screen text for advertising, and
does not upload screen content except the current task's text to the
user-selected model endpoint.

## Request reason (copy this)

HarmonyOS gives third-party apps no other on-device way to read and operate
another app's UI. Screen capture plus input injection is not available to
ordinary apps, and the PC bridge requires a computer, which defeats the purpose
of a phone agent. The accessibility extension is the only transparent,
user-enabled mechanism: the user turns it on in Settings, sees HOPA's actions,
and can revoke it at any time. The app is phone and tablet, API 22+, and the
permission is used only when the user asks HOPA to operate an app.

## After approval

1. AGC → **Certificates, app IDs, and profiles → Profiles**.
2. Create a **debug** profile for `com.hopa.agent`.
3. Add the **Mate 80 UDID** and select the approved ACL permission
   (`Restricted ACL permissions (HarmonyOS API 9 or later)`).
4. Download the `.p7b`.
5. Sign the full build (the one with the permission in `module.json5`) with
   that profile and the matching `.p12`/`.cer`, then `hdc install`.
6. On the phone: Settings → Accessibility → HOPA → enable.

The PC bridge can then be disconnected; HOPA works on the phone alone.

## If it is not approved quickly

Use the PC bridge. It is the only working control path today, but it is
tethered: the phone must stay on the same network as the bridge PC, and the PC
must run the bridge process.
