# Changelog

All notable changes are recorded here. Versions follow `docs/versioning.md`.

## Unreleased

### Added

- A cloud relay for the bridge: `pc-agent relay` runs on a public web service
  and `pc-agent cloud-link` keeps a PC dialled out to it, so the phone works
  without a USB tunnel or a port forward. The relay forwards verbatim, so the
  device lock, tokens, run records and `/chats` stay on the PC. Its 25-second
  long-poll is also the keep-alive that stops Render's free tier from sleeping;
  `/health` reports `linked` and `link_age_seconds`.
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
- The bridge now keeps a **shared image store** (`POST /images` by content
  hash, `GET /images/<id>` behind the device token, `~/.hopa/images`). It is
  the transport a phone's run screenshot needs before the laptop can show it:
  a sandbox path means nothing on another device.

### Changed

- The product is named for what it is: **HOPA — the HarmonyOS Personal
  Assistant**. Every string a person reads says "assistant" — the phone's ten
  locales, About, the welcome tour, the recap card and the system prompt — and
  "agent", "phone" and "on-device" are gone from the product's own description.
  The code keeps its `agent` names; only the claim changed.
- The front page is the banner plus one promise. `docs/media/banner-2026-duo.svg`
  shows a single request in three frames — **You say it**, **HOPA does it inside
  your apps**, **You see it done** — where the middle frame is still HOPA with the
  other app docked as a window inside the chat, its draft marked *not sent* until
  it is. The README leads with what a person wants (their apps, their money) and
  keeps the two devices as the later payoff. `CONTRIBUTING.md` and the PR
  template now require the banner and the README to move in the same change.
- The composer is inset by padding on a wrapper `Row` and fills the rest with
  `layoutWeight(1)`, so its edges sit exactly on the message column (left under
  the HOPA mark, right where the answer and the user bubble end) at every
  window width. `width('100%')` plus padding or margin overflowed the parent
  and was clipped, which made earlier attempts look uninset.
- The laptop details rail no longer echoes the last request — it is already the
  centre of the screen. The rail now carries only facts the conversation cannot
  show: measured timing when one exists, and the bridge's real status.
- The structure checker and the app-catalogue generator follow the
  `app` / `phone` / `laptop` split, so the CI gates measure the real modules
  again; the four files that were already over budget are listed as
  grandfathered debt in the remaining-work table.
- The laptop rail is now an inspector **card**, not a third column: it mounts
  only when there is a run, a consent or a measurement, and a plain chat keeps
  the width. Anatomy: `THIS RUN` / `LAST RUN` / `YOUR OK` title, a status line
  (`Succeeded · 3 steps · 4.2 s`, `Failed at step 2`, `Working…`), quiet
  `Copy · Retry · Undo` ghost verbs, numbered steps with the outcome and duration,
  the frame that was read (selectable per step), up to four earlier runs in the
  same chat with a link to Activity, measured cost when it exists, and a pinned
  bridge line. An older run says `Earlier: …` so the pane never lies about which
  answer it describes.
- The pane observes; it does not command. `Copy` lives on the last answer,
  consent lives in the card, and undo lives on the Activity row that knows the
  app and the question. `Ask again`, `Copy run`, `Copy answer` and `Close app`
  were tried in the pane and removed: the composer and the Activity row are
  where those actions have context.
- The header is silent while the PC bridge is healthy, as every modern shell
  is; only the exception earns chrome (`No bridge · Set up`, which opens
  Settings). The permanent status dot and the word "Bridge" are gone.

### Fixed

- Opening a system app (Settings, Browser) failed with "could not open … here"
  because `getLaunchWantForBundleSync` does not resolve them on this build. The
  launcher now falls back to an explicit ability Want (`<bundle>.MainAbility`,
  `<bundle>.EntryAbility`, then the bare names), so the action HOPA was asked
  for actually happens.
- Answers written on the phone leaked their machine line into the chat as
  `⟦meta⟧steps=✓ …`, because the laptop stripped only ASCII `[meta]`. The shell
  now reads the same stored form as the phone (`ChatFormat.textOf` /
  `stepsOf`), so the line disappears and its steps become real steps in the
  rail — which is also why the pane can show a phone-run answer again.
- A phone that had not yet paired was refused by the pooled bridge
  (`400 say which device`): `/pair` now belongs to the phone, like `/sessions`,
  because at that moment the caller has no credential with which to name itself.
  With two devices in the pool, the setup wizard could never complete.

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
