# A11 - feature screens

Date: 2026-11-13. One item is complete: the Capabilities hub.

## Capabilities hub

`CapabilitiesScreen` follows `CapabilitiesPage.ets`: readiness card with the
mascot, model and control state, `WHAT HOPA CAN USE` (Launchpad, Browser, Memory,
Runs) and `TOOLS` (Usage, MCP servers, Skills), plus the `Settings` pill in the
52 dp header. Tiles without a screen say "not on Android yet" instead of
pretending.

Screenshot: `docs/media/android-capabilities-2026-11-13.png` (older styling);
the current tabbed version was checked on the emulator on 2026-11-13.

## Partly there, not ticked

- Chats sheet: search, date groups, New chat, Current, swipe delete with confirm,
  delete-all — but no rename and no long-press menu.
- Activity: status card, last run, week counters, recent actions — the week
  share sends text, not the generated image.
- Launchpad: installed apps with search and a Launch intent — not the shared
  catalogue with segments and verified flags.
- Settings: provider/model form only; no agent switches, appearance, character,
  parent PIN, bridge wizard, logs or self-check.

## Missing

Runs filters/detail/replay, Usage, Plans, Browser, Memory, Skills, device control,
the full Settings tree, the inbound share target, MCP and License pages.
