# A11 - feature screens

Date: 2026-11-13/14. One item complete: the Capabilities hub. On 2026-11-14
Usage was added and Runs gained filters and a detail dialog.

## Capabilities hub

`CapabilitiesScreen` follows `CapabilitiesPage.ets`: readiness card with the
mascot, model and control state, `WHAT HOPA CAN USE` and `TOOLS`, plus the
`Settings` pill in the 52dp header. Tiles without a screen say "not on Android
yet"; Usage and Runs now navigate.

## Usage (2026-11-14)

`UsageScreen` counts `run_records`: total actions, succeeded, failed, payments,
last seven days, and the top action kinds. Verified on `emulator-5554`: two
launch records showed `2 actions`, `2 succeeded`, `0 failed`, `0 payments`,
`last 7 days 2`, `ui.launch ×2`.

Reachable from Activity (`Usage` card) and Capabilities (`Usage` tile); it was a
toast before.

## Runs (2026-11-14)

- Filters: All / Payments / Failed.
- A record opens a dialog with step, action, classification, approved
  (or "not asked"), executed, verified, error, the hash, and **Verify chain**.
- On the emulator the dialog showed the fields and `Chain: ok` for a stored
  record (the recorder re-walks `prevHash`/`hash`).

Still open for the Runs item: replay with a filmstrip, batch actions, clear.

## Partly there, not ticked

- Chats sheet: search, date groups, New chat, Current, swipe delete, delete-all,
  sync — but no rename and no long-press menu.
- Activity: status, last run, week counters, recent actions — the week share
  sends text, not the generated image.
- Launchpad: installed apps with search and a Launch intent — not the shared
  catalogue with segments and verified flags.
- Settings: model/bridge/phone access; no agent switches, appearance, character,
  parent PIN, bridge wizard, logs or self-check.

## Missing

Browser, Memory, Skills, device control, the full Settings tree, the inbound
share target as a file/image target, MCP and License pages, Plans.
