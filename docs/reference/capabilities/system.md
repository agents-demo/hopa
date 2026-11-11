# System intents

Status: **partly implemented.** The Easy and Kid homes delegate calls, messages
and app launches through `Want`s; the share target is a real
`ShareExtensionAbility`. The `SystemCapability` executor itself is still a stub
for alarm, calendar and deep-link actions.

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

## Wired today

- **Call** (Easy): in-app number pad, then `ohos.want.action.dial` with
  `tel:<number>`, falling back to `com.ohos.contacts`. The pad closes first, so
  a slow hand-off never freezes it.
- **Message** (Easy): `com.ohos.mms`.
- **Share target**: `HopaShareExtension` (`type: "share"`) accepts
  `general.text`, `general.image` and `general.file`, reads the payload with
  `systemShare.getSharedData`, previews it in `pages/share/ShareSheet` and hands
  it to the conversation through `hopa.sharedText`.

## Rules

- Prefer public `Want` routes over private APIs.
- Validate the URI scheme and host before `startAbility`.
- Stop before emergency numbers (`110 / 112 / 119 / 120 / 122 / 999`).
- Install and uninstall ask first; the package name is shown.
- Settings deep links use documented `Want` actions only.
- A share never acts on its own: the sheet hands text to the composer, and
  approvals still apply to whatever is asked next.

## Gaps

- `SystemCapability` does not start alarm, calendar or deep-link `Want`s yet.
- No calendar/contacts permission flow.
- Image and file shares arrive as a path; HOPA cannot read their contents yet,
  and the sheet says so instead of pretending.
- Shares are not covered by a device test yet; the picker is a protected system
  window, so verification is manual.
