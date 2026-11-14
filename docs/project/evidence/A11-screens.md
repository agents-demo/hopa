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

## Device control (2026-11-14)

- The Capabilities status card opens `Device control`: one card for the PC bridge
  (not configured / configured, not checked / connected / unreachable, with the
  address and error), one for the on-device service (off / enabled, not
  connected / enabled and connected), a Retry that calls `/health`, buttons to
  the Bridge settings and Phone access, and an honest "HOPA cannot act yet" line
  when neither path is ready.
- The statuses poll every two seconds, so enabling the service in Android
  settings updates the page without leaving it.
- Verified on emulator-5554: the page rendered both states, the bridge address
  and the honesty line.

## Memory and Skills (2026-11-14)

- Room v4 adds `memory_facts` and `skills` with `MIGRATION_3_4`; `RoomMemoryStore` and `RoomSkillStore` own add/delete/clear/export text.
- `MemoryScreen` has a MEMORY section (add a fact, delete one, clear all) and a SKILLS section (phrase -> action), plus Export via the share sheet.
- `ChatViewModel` passes `memory.promptText()` and `skills.promptText()` into `TurnContext`, so the system prompt carries both; Capabilities shows the fact and trigger counts.
- Verified on emulator-5554: the v4 migration kept the app running; saved `my name is Michael` and the skill `focus -> open Settings`; both lists rendered.

