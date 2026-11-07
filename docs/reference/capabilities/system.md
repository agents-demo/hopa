# System intents

Status: **stub.** `SystemCapability` accepts the calls but does not start the
corresponding system abilities yet.

## Design

| Action | Route | Approval |
|---|---|---|
| `system.setAlarm` | `Want` to the Clock app, or the public timer API | no (reversible) |
| `system.addEvent` | Calendar provider APIs with user-granted permission | no |
| `system.openLink` | `Want` with scheme/host allow-list | yes (sensitive) |
| `system.share` | Share sheet | yes |
| `system.sendMessage` | Messages ability | yes |
| `system.call` | Telephony intent; emergency numbers blocked | yes |
| `system.delete` / `uninstall` / `reset` | Only with explicit approval | yes |

## Rules

- Prefer public `Want` routes over private APIs.
- Validate the URI scheme and host before `startAbility`.
- Stop before emergency numbers (`110 / 112 / 119 / 120 / 122 / 999`).
- Install and uninstall ask first; the package name is shown.
- Settings deep links use documented `Want` actions only.

## Gaps

- No `Want` is started yet.
- No calendar/contacts permission flow.
- No share sheet.
- No tests on a device.
