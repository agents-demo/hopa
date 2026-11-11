# Changelog

All notable changes are recorded here. Versions follow `docs/versioning.md`.

## Unreleased

### Added

- Bridge token rotation: `/pair` returns an access token plus a refresh token
  and `expires_in`; every pair or refresh rotates both. The phone stores the
  pair in Asset Store and renews silently when a request comes back
  `401 token expired`.
- The 2in1 shell drives its own machine through a second `pc-agent bridge`
  (port 8767, `rport` restored by `deploy.ps1`): observe, screenshot, tap,
  type, swipe, key and launch, registered as the shared `RemoteUiCapability`,
  with the bridge as its screen source. Settings gains a **PC bridge** section
  that reports `Connected.` only after a real `/health` answer.
- The laptop approval card shows the last frame the bridge captured, labelled
  **WHAT HOPA SAW**, so the consent is given against evidence rather than a
  description.
- One bridge process now serves every device (`--devices`), with the caller
  naming its device through `X-Hopa-Role` or `/d/<serial>/...`; tokens stay per
  device, and `/sessions` resolves to the phone unless `X-Hopa-Read` asks for
  the other side. hdc only allows one device per device-side port, so the phone
  tunnels 8768 and the 2in1 8766.
- Left pane, restructured to the chat-app shape: **New chat → Search (Ctrl K)
  → conversations grouped Today / Previous 7 days / Earlier → Settings**. The
  Commands, Browser, Plans and Activity rows left the pane; they are header
  tools now (Log · Plans · Web), and the mascot + HOPA exist once, in the hero.
  Rows are 30 px, the selected one is a soft fill, and the delete `×` appears
  only on hover. Ctrl+K was matched against the wrong key code (2070 vs 2027),
  so the palette shortcut had never worked; it does now.
- Composer spacing fixed (two padding calls had collapsed the pill's inner
  margins); message type now follows the mode (Easy 15, Kid 16, Power 13,
  others 13.5); Power keeps the details metrics, Easy/Kid/Social do not, and
  Social hides the details rail.
- The bridge's bootstrap token now survives pairing and restarts; paired tokens
  still rotate. A dev laptop is no longer stranded by a bridge restart.
- Composer: one primary button (mic when empty, Send when not, Stop while
  running); Enter inserts a line break and only **Ctrl+Enter** sends; the
  question appears in the transcript immediately instead of after the answer.
- Undo: a run record keeps what it acted on, the bridge can close an app, and
  Activity offers **Undo** on a launch — verified: Settings closed and HOPA came
  back to the front.
- Settings is four pages (Model, Bridge, Modes, About) instead of one scroll.
- Kid hides the history browser (one thread, no list), and the completion
  notification carries a **Stop** action that cancels the run.
- Schedules are shared: `ScheduleService` moved into the kit, the laptop runs it
  against its own runtime, and a **Plans** page adds and removes them
  (hourly/daily) while HOPA is open.
- Sync integrity: turns are never identified by their position. An adopted turn
  keeps the id the sender had, and a turn without an id merges by role, time
  and text. A position-based id made every sync look like new messages and grew
  a single thread to a thousand turns; the store now self-heals on load by
  collapsing adjacent and periodic repeats, and `/whoami` makes “Connected”
  mean a working key rather than an open port.
- Fixes from device testing: switching sessions on the laptop now replaces the
  transcript (the list keyed rows by index, so equal-shaped sessions reused the
  old rows); Activity reads run records saved before turn ids existed;
  `[meta]` lines from phone turns are stripped on the laptop; the browser has a
  Close button and an unloadable-page message, and picking any session returns
  the pane to chat.
- `POST /focus` brings HOPA back after a run left it: `aa start` alone cannot
  raise a singleton window on the 2in1, so the bridge falls back to one cold
  restart and reports whether it did.
- Run records carry what changed on screen (`+3 -1 lines · …`), computed where
  the executor already compares the before and after observations.
- B7: HOPA's own browser pane on the 2in1, exposed to the runtime as a page
  source (`document.body.innerText`), with “Ask about this page”. Verified: it
  answered “the page open in the browser is example.com…” from the page itself.
  Binding `src` to state re-created the Web view and dropped the shell back to
  chat; navigation now goes through `loadUrl` only.
- Notifications: “Tell me when an answer is ready” toggle; publishing happens
  only when HOPA is not the window in front.
- Voice on the 2in1: the mic records 16 kHz mono here, the PC bridge
  transcribes it (`/transcribe`) and speaks replies (`/speak`) when “Speak
  replies” is on. Without a bridge the button says so instead of pretending.
- Conversations now live on the bridge (`/chats`), one store for both devices:
  append-only turns with ids, last-writer-wins titles, delete tombstones and a
  revision. Each shell pushes on launch and after an edit and adopts the merged
  answer, so the list is the same on the phone and the laptop and any thread can
  be continued on either. The “From your phone” section, the origin badge and
  **Continue here** are gone.
- The phone's conversation store notifies its listeners once it has loaded, so
  the session relay no longer pushes an empty snapshot at boot; the laptop also
  refreshes the phone list on focus and on a slow timer.
- The bridge persists the conversation snapshot, and the phone pushes it once at
  boot, so a restarted bridge does not lose history.
- The bridge persists its token pair and read-only sessions key in
  `~/.hopa/bridge-<port>.json`, so a restart inside the TTL no longer forces a
  re-pair (`--state`, `--no-state`). `tools\scripts\bridges.ps1` starts,
  reports or stops one bridge per device (8766 phone, 8767 2in1) and
  `deploy.ps1` calls it.
- The 2in1 package is now honest about its target: `2in1` and `tablet` only,
  a laptop-bodied launcher icon in the module, and a 960x620 minimum window so
  the sidebar, rail and composer cannot be crushed.

### Changed

- The composer is inset by padding on a wrapper `Row` and fills the rest with
  `layoutWeight(1)`, so its edges sit exactly on the message column (left under
  the HOPA mark, right where the answer and the user bubble end) at every
  window width. `width('100%')` plus padding or margin overflowed the parent
  and was clipped, which made earlier attempts look uninset.
- The laptop details rail no longer echoes the last request — it is already the
  centre of the screen. The rail now carries only facts the conversation cannot
  show: measured timing when one exists, and the bridge's real status.

## 0.1.0 — 2026-11-06

### Added

- PC reference loop: observe → decide → gate → act → verify → record.
- v1 JSON schemas for observation, action, decision and run record.
- Payment classification from the screen, never from a model flag.
- Emergency-number block, password/OTP typing refusal, URL policy, rate limits
  and per-task tool allow-lists.
- Hash-chained, redacted run records with `verify-chain`.
- OpenAI-compatible client with retry and one repair attempt.
- Kotlin brain: lexical router, `ChannelAdvisor`, `/decide`, sessions, `/knowledge`.
- 12 HarmonyOS system app knowledge files with a strict front-matter loader.
- Prompt contract with intent gate, channel order and truncation.
- 20 HOPA-Bench task definitions and a report aggregator.
- ArkTS screen-aware approval policy and an observation-fed `AgentLoop`.
- ADRs 0001–0006, contracts, threat model, privacy, safety and status docs.
- CI: Python tests, ruff, plan lint, Kotlin build and contract test.

### Known limitations

- The HAP is unsigned.
- The accessibility extension is not declared; no ACL has been filed.
- The entry UI is still a shell.
- No device bench or real-model run has been recorded.
- API 26 is not installed; the local build uses API 24.
