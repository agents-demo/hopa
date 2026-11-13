# Android app development plan

Status: **v2 after critique; not started.** Written 2026-11-13 from a full read of
the HarmonyOS phone code (UI, core, capabilities, shared services, bridge).
Owner: TBD.

Builds an Android client with the **whole agent loop inside the APK** (ADR-0016)
that acts through **two paths** (ADR-0017): the PC bridge over `adb` (primary) and
an on-device `AccessibilityService` (fallback). Behaviour is defined by
`contracts/schemas` and `contracts/fixtures`.

Count it with:

```bash
python tools/scripts/plan-status.py --plan docs/project/plan/android
```

Evidence for every phase goes to `docs/project/evidence/A<N>-<slug>.md` (commands,
transcripts, screenshots, APK hash). A phase is done when its gate passes on the
stated target, and the artifact exists.

---

## 1. Goals

1. Feature parity with today's HarmonyOS phone app, with the same contracts and
   the same honesty about what failed.
2. Two execution paths behind one seam, selectable, with an honest status line.
3. Offline core: loop, model, sessions and records work without a PC; the bridge
   adds device control, voice and sync.
4. `core` free of Android imports, proven by the conformance fixtures on the JVM.
5. Sideload-first release: signed APK, no store dependency at the start.

## 2. Non-goals

- No backend or account (ADR-0011 remains a hosted option).
- No iOS; no HarmonyOS code changes beyond the shared bridge/contracts work.
- No invented features beyond parity plus platform necessities (insets, back,
  foreground service, share target).
- No Play-only assumptions for the accessibility path.

## 3. Decisions taken

| Decision | Where |
|---|---|
| Each client owns its loop; shared schemas + fixtures | ADR-0016 |
| Bridge/adb first, accessibility fallback | ADR-0017 |
| Kotlin + Compose, `apps/android`, minSdk 30 / target 35 | this plan |
| BYOK; key only in Keystore | ADR-0016 |
| Sideload/internal first | ADR-0017 |
| `shortService` FGS type for bounded runs (API 34) | this plan (new) |

## 4. Parity source, corrected by the critique

Facts below were verified against the code. Where the first draft was wrong, the
correct value is marked **(corrected)**.

### 4.1 Screens

23 reachable screens plus share sheet; **three** dead pages: `models`, `source`,
`license` **(corrected: was two)**; Settings rows Files/Welcome/License fall
through to About.

| Screen | Harmony file (lines) | Android phase |
|---|---|---|
| Shell, bars, chat sheet, approval overlay | `phone/pages/Index.ets` (689) | A9 |
| Chat | `pages/chat/ChatPage.ets` (1187) | A9 |
| Chats sheet | `navigation/ChatsSheet.ets` (284) | A9 |
| Easy/Kid/Power/Social homes | `pages/home/*.ets` (726/794/318/402) | A10 |
| Easy history | `pages/home/EasyHistory.ets` (180) | A10 |
| Activity, Runs, Plans, Usage | `pages/{activity,runs,plans,usage}` (456/580/267/158) | A11 |
| Capabilities, Launchpad, Browser | `pages/{capabilities,apps,browser}` (157/281/155) | A11 |
| Memory, Skills, MCP | `pages/{memory,skills,mcp}` (252/105/36) | A11 |
| Device control (ex Phone setup) | `pages/phone/PhonePage.ets` (172) | A11 |
| Settings + 11 sub-pages | `pages/settings/*` (880 + 340 + 383 + 134 + …) | A11 |
| Live screen, Self-check, Welcome, About, Files | `pages/tools/*` | A11 |
| Share target (inbound) | `extension/HopaShareExtension.ets`, `ShareSheet.ets` | A11 |
| Models, Source, License | routed but unreachable | **do not build** |

### 4.2 Behaviour facts that change the work

- **Step budget: 14**, not 10; 6 on the automation launch path
  (`AgentRuntime.ets:100,241`; `EntryAbility.ets:113`). 10 is the unused
  `AgentLoop` default.
- **31 action kinds in the schema**; the parser emits 19, and its set differs
  from the schema (`a11y.observe`, `sandbox.runNetworked` are not in the schema;
  `ui.stop`, most `system.*`, all `payment.*` are unreachable). The contract is
  the authority on Android.
- **Sensitive kinds mismatch**: Harmony guards `ui.sendMessage`/`ui.call`; the
  schema names them `system.sendMessage`/`system.call`. The trusted-app shortcut
  is dead code today; Android must implement it against the schema names.
- **Approval classification** is `read|sensitive|payment`; "PUBLIC" is UI copy,
  not an enum value.
- **Run records**: Harmony's audit record (`domain/RunRecord.ets`) has no hash
  chain. The contract record has one. Android implements the **contract** record
  and keeps the display fields (`shot`, `changed`, `isPayment`) as additional
  UI-facing data.
- **Tombstones are ephemeral on the phone**: an in-memory `removed[]`, never
  persisted, cleared on adopt; the store grows `deletedAt` but snapshots filter
  deleted sessions out. Android must persist tombstones.
- **Bridge timeouts** differ per method: POST 8/45 s, GET 8/20 s, pair/refresh
  8/15 s. 8/45 is not universal.
- **`/health` on a single-device bridge returns `{ok:true}`**; only the pool
  lists devices. `BridgePool` hardcodes `HarmonyDevice` and derives its role from
  `param get`.
- **`DevicePort` has no `screenshot` or `apps`** (`device_port.py`). The HTTP API
  has `/screenshot` but **no `/apps`**; the concrete `HarmonyDevice` has `apps()`.
  A5 extends the protocol and adds the endpoint.
- **Share is inbound** (a target for text/image/file, max 1) and `ACTION_PROCESS_TEXT`;
  outbound is clipboard and `systemShare`. The plan must not treat it as one
  outbound sheet.
- **17 approval policy cases**, not 18.
- **7 settings sections**, 11 sub-pages.
- Verified: 24 000-char budget / last 6 / 400-char old lines; 120-line element
  cap; 20 000-char browser text; 600-char speak; 4 MiB images; 12 h tokens and
  5/min pair+refresh; 100-record archive; 26 settings fields with
  `notifyAnswers` never persisted.

### 4.3 Known Harmony defects: do not copy

1. Three dead pages and three Settings rows opening About.
2. Empty-state "continue last conversation" never rendered; dead props.
3. `shotId` written, never displayed.
4. No chat rename, no delete-all, delete only by swipe.
5. Phone delete is local-only and resurrects.
6. Selection not persisted; cold start may open another chat.
7. Empty merged list indistinguishable from failed sync.
8. `ChatSync` keeps the old token after refresh.
9. Prompt says "no web" while the router recommends `web.navigate`.
10. Kid guard is a client-side regex (UX, not security).
11. No redaction before prompt/records despite docs claiming it.
12. `RunStore` in-memory; a crash can lose the record.

---

## 5. Architecture

```
apps/android/
├─ app/            Compose UI, navigation, DI, foreground service, share target
├─ core/           loop, parser, prompt, budget, gate, records, ports (pure Kotlin)
├─ capabilities/   device adapters, observation producer, llm, browser, system,
│                  sandbox, voice, bridge client
├─ data/           Room (sessions, runs, pending approvals), DataStore, Keystore
└─ androidTest/    conformance runner, Compose tests, emulator/device suites
```

### 5.1 Ports (`core` owns the interfaces)

| Port | Answers | Android implementations |
|---|---|---|
| `DevicePort` | observe/act/capture | `AdbDevice`, `AccessibilityDevice` (screenshot and apps must be **added** to the port) |
| `SystemPort` | `system.*` (alarm, event, link, share, call, message, delete, uninstall, reset) | platform services / bridge shell |
| `BrowserPort` | `web.*` | WebView + JS bridge (no browser over the bridge; say so) |
| `SandboxPort` | `sandbox.run` | WebView JS only |
| `VoicePort` | record, transcribe, speak | `AudioRecord` + bridge, TTS fallback |
| `Clock` | now, settle, timeouts | injected; makes loop tests deterministic |
| `PackageCatalog` | installed apps, verified flags, launch intent | `PackageManager` + a new Android catalogue |
| `ObservationProducer` | screen → observation (refs, redaction, caps, hash) | one implementation, used by **both** device adapters |
| `ScreenSource` | choose bridge / accessibility / browser text | a composition with an explicit precedence |
| `RunRecorder`, `ApprovalGateway` | record, ask | Room recorder, service-owned approval |

`core` has no `android.*`; the composition root is `app`.

### 5.2 Execution planner

States, resolved at the start of every action:

| State | Condition | Behaviour |
|---|---|---|
| `BRIDGE` | a bridge is configured, `health` and `whoami` pass, target is the bridge device | use `AdbDevice` |
| `BRIDGE_UNREACHABLE` | configured but failing | fall back to `LOCAL` if granted, else fail with an honest reason |
| `LOCAL` | accessibility granted and enabled | use `AccessibilityDevice` |
| `NONE` | neither | chat and plan only; every action returns an honest refusal |

Rules: an explicit user override wins; the planner re-checks per action (a bridge
can die mid-run); **the self-in-front guard** refuses to observe/act while HOPA's
own window is foreground (Harmony has this in `RemoteUi`/`AppFocus`); accessibility
revoked mid-run fails closed.

### 5.3 ObservationProducer (new, required)

Refs in pre-order (`e1…`, empty root ref), password-ish fields dropped, emails /
phones / card numbers / OTPs redacted, 400-node cap keeping the focus path,
6 000-char text cap (20 000 for browser pages via `BrowserPort`), canonical
`sha256` hash. This is what makes `observationHash` in run records real and what
stops secrets reaching the prompt.

---

## 6. Phases

### A0. Project, toolchain and Android prerequisites (5 d)

- [ ] Gradle project with version catalog, JDK 17, AGP/Kotlin/Compose; `minSdk 30`, `targetSdk 35`.
- [ ] Modules `app`, `core`, `capabilities`, `data`; a Gradle check rejects `android.*` in `core`.
- [ ] ktlint/detekt + Android Lint; zero warnings on `core`.
- [ ] Wrapper committed; `.gitignore` for SDK/keystores/build.
- [ ] **Cleartext policy**: `networkSecurityConfig` allowing private ranges only (bridge on LAN/loopback); no global cleartext.
- [ ] **Package visibility**: `<queries>` for the catalogue and `getLaunchIntentForPackage`; no `QUERY_ALL_PACKAGES`.
- [ ] **FGS type**: `shortService` + `FOREGROUND_SERVICE` permission, `POST_NOTIFICATIONS` request and denied path.
- [ ] `FileProvider` and SAF (`ACTION_CREATE_DOCUMENT`) wiring; no `file://` sharing.
- [ ] Permission matrix in the manifest: INTERNET, RECORD_AUDIO, POST_NOTIFICATIONS, FGS, accessibility service declaration (disabled until A7).
- [ ] CI: assemble debug, `:core:test`, lint, APK artifact, Gradle cache.
- [ ] Evidence: CI green, APK installs on an emulator, cleartext config proven by connecting to a LAN fixture.

### A1. Contracts and schema validation (5 d)

- [ ] `core/contracts`: serializable `Observation`, `Action`, `Decision`, `RunRecord` matching the schemas exactly (names, nullability, unknown fields rejected).
- [ ] JSON-Schema validation with `networknt/json-schema-validator` (draft 2020-12), including `action` `$ref` inside `decision`; pin the version.
- [ ] `ObservationProducer` contract tests: pre-order refs, redaction cases, 400-node cap with focus path, 6 000-char cap, canonical hash vector.
- [ ] Schema-only conformance: every fixture's observation and decision validates or fails as declared; no semantic gate yet.
- [ ] A named negative case: `ui.teleport` must fail with `E_SCHEMA`.
- [ ] Evidence: JVM tests; an intentionally invalid fixture fails with the schema error.

### A2. The loop (10 d)

- [ ] `AgentLoop`: initial capture, system prompt, **up to 14 steps**, 1500 ms settle, duplicate-launch short-circuit, cancel at three checkpoints, final text-only call, `summarize`.
- [ ] `ActionParser`: fenced/last-object parsing, the **schema's** kinds (not Harmony's 19), reject `finish`/`done`, ignore model payment flags, unknown kind → text.
- [ ] `PromptBuilder`: system text, memory/skill/app-catalogue blocks, router hint, screen rendering with 120 element lines.
- [ ] `ContextBudget`: 24 000 chars, keep last 6, 400-char old lines, hard trim.
- [ ] `RunNarrator`: per-step sentences, tap grouping, failure phrasing.
- [ ] `ObservationProducer` wired behind `ScreenSource` (bridge → accessibility 4 s guard → browser text).
- [ ] Loop tests: payment stops at first step, cancel, token accounting, launch dedupe, 14-step cap, parser cases (from `ActionParser.test`), budget cases.
- [ ] Evidence: stub-model turn produces outcomes and an answer; tests mirror the Harmony core suite.

### A3. Gate, records, semantic conformance (8 d)

- [ ] `ApprovalPolicy`: all sets from `ApprovalPolicy.ets`, amount/merchant regexes, trusted-app rule against `system.sendMessage`, fail-closed; autonomous never bypasses payment.
- [ ] `ActionExecutor`: guards → policy → approval → capability → verify → record; denial records; unsupported records.
- [ ] `RunRecord` per **contract** with `prevHash`/`hash` (canonical JSON, `sha256:`), step index, trace id; seed pinned to `sha256("")`; `verifyChain` fails on tamper.
- [ ] Room `RunStore` (last 100, atomic), `beginTurn` always called.
- [ ] Approval content: title/body, amount/merchant, highlight bounds, payment checkbox, remember-app for messages.
- [ ] **Full conformance runner** (the six fixtures) with a fake capability per classification; a broken client fails the fixture name.
- [ ] 17 policy cases + executor cases (denied, unsupported, approved payment, screen-diff verify).
- [ ] Evidence: policy/executor/chain tests green; a tampered record fails; all six fixtures pass.

### A4. Model, keys, settings core (6 d)

- [ ] OpenAI client: `max_tokens: 2048`, `reasoning_effort: low`, 30/60 s, token usage, empty-content errors.
- [ ] Anthropic and Gemini clients; `ModelFactory`.
- [ ] Keystore AES-GCM: `hopa_model_key`, `hopa_bridge_session`; no plaintext; no logging.
- [ ] Settings repository (DataStore) with all 26 fields + `notifyAnswers` **persisted**; typed keys.
- [ ] Model settings UI is only the form; no general Settings screen yet (A11).
- [ ] Tests: request body snapshot, error mapping, key round-trip, no secret in logs, settings round-trip.
- [ ] Evidence: a real turn using A2+A3; unit tests green.

### A5. Bridge `adb` transport (10 d, `services/bridge`)

- [ ] Design note first (0.5 d): `platform` field, CLI `--platform`, `/health` shape, role detection.
- [ ] `adb` transport: devices/shell/exec-out, serial targeting, timeouts, retries.
- [ ] `device_android.py`: `uiautomator dump` parser (active window only, importance filtering, idle-state failure), `input tap/swipe/text/keyevent`, `am start` via `resolve-activity`/`monkey`, `am force-stop`, `screencap -p`, `dumpsys window`, `pm list packages`.
- [ ] `BridgePool`: factory accepts `platform`, no hardcoded `HarmonyDevice`; role/type detection per platform.
- [ ] Non-ASCII typing: ADBKeyboard IME path or explicit refusal pointing to accessibility; document both.
- [ ] `/apps` endpoint (`pm list packages -3` plus labels) and `apps()` on `DevicePort`; `screenshot()` on `DevicePort` (the handler exists, the protocol does not declare it).
- [ ] Tests: layout fixtures, command construction, fake runner, pool routing; hardware smoke.
- [ ] `contracts/openapi/bridge.v1.yaml`: add `platform` and `/apps`; keep existing paths stable.
- [ ] `services/docs`: `adding-a-platform` updated with the adb reality.
- [ ] Evidence: bridge lists an Android device with `platform: android`; observe/tap/screenshot work.

### A6. `AdbDevice` adapter and bridge UX (7 d)

- [ ] `BridgeClient.kt`: per-method timeouts, one 401 refresh, URL/token scrub, role/target precedence.
- [ ] `AdbDevice`: observe/tap/type/swipe/launch/stop/foreground/**screenshot**/**apps** (the last two call the bridge endpoints added in A5; `DevicePort` is extended there).
- [ ] Pairing: code → token+refresh in Keystore; a **single token holder** shared with `ChatSync`.
- [ ] Target selection: this device vs bridge device; persisted.
- [ ] Connection UI: address, pair code, connect, `health` then `whoami`, honest failure reasons.
- [ ] Tests: fake HTTP for every endpoint, forced 401 → rotation updates both clients, scrub cases (full-width), unreachable mid-run.
- [ ] Evidence: full turn on emulator via bridge; before/after text diff proves the tap; screenshot artifact.

### A7. `AccessibilityDevice` (16 d)

- [ ] Service declaration, `accessibilityServiceInfo` (`canTakeScreenshot`, flags), disclosure screen, kill switch, self-package event filtering.
- [ ] Tree capture → `ObservationProducer` (same observation as A6 for one fixture screen).
- [ ] Gestures: tap/double/long/swipe/back/home/scroll via `dispatchGesture`.
- [ ] Typing: `ACTION_SET_TEXT`, focus first, clipboard/IME fallback; non-ASCII.
- [ ] Screenshot: `takeScreenshot` with `FLAG_SECURE` handling and ~1/s limit; tree-only fallback.
- [ ] Service death/revocation: re-check `enabledServices` before each action; fail closed.
- [ ] Background capture: only while the service is enabled and the app is in a run; disclosure text matches behaviour.
- [ ] Tests: fake tree, ref stability, action mapping, permission denied, revocation mid-run.
- [ ] Evidence: a full turn on a real phone with the bridge **uninstalled/disabled**; both adapters produce identical observations for the fixture screen.

### A8. Data, sessions, sync (10 d)

- [ ] Room: `sessions`, `turns`, `run_records`, `pending_approvals`; JSON field names compatible with `ChatSync`.
- [ ] Repository: new chat (reuse one draft), **selection persisted**, delete → persisted tombstone, delete-all, no resurrection.
- [ ] Titles from the first user message; active pinned; ordering by `updated`.
- [ ] `ChatSync`: push whole set, adopt merged snapshot, **pull fallback**, tombstone growth, draft protection, shared token holder.
- [ ] Images: upload/download, cache, id only in synced turns, 4 MiB cap, stream to file.
- [ ] Merge tests: delete on A + edit on B (resurrection), title conflict, id-less turns, rotation mid-sync, failure keeps local.
- [ ] Evidence: two clients/bridge see one thread; delete propagates and stays deleted; failure keeps data.

### A9. UI shell, chat, composer, approval (14 d)

- [ ] `Scaffold` + `NavHost` typed routes; predictive back → in-app back; deep link `hopa://ask?text=`; app shortcuts "Ask HOPA"/"Last run".
- [ ] Top bar per screen; profile-aware bottom bar; chat sheet modal; approval as a **service-owned** pending state (survives rotation/process death, deny on death, timeout).
- [ ] Chat: LazyColumn stable ids, bubbles, step chips, verification line, "What HOPA saw", changed chip, undo, retry, copy, share via `FileProvider`.
- [ ] Composer: hardware Enter/Shift+Enter **and** IME action Send; four-state round control; dictation fills only; `imePadding`.
- [ ] Empty state: greeting, 3 suggestions, examples toggle.
- [ ] Approval sheet: badge (read/sensitive/payment wording), amount/merchant, highlight crop, payment checkbox, remember-app for messages, deny/allow.
- [ ] Accessibility: 48 dp targets, content descriptions, headings, 200% font scale, TalkBack pass on chat + approval.
- [ ] State restoration: draft `rememberSaveable`; run and pending approval outside composition.
- [ ] Evidence: screenshots of chat/empty/approval; TalkBack transcript; rotation keeps run + approval.

### A10. Profile homes and history (8 d)

- [ ] Everyday = chat (A9); Easy home: greeting by hour, talk sheet (input/working/done), "Read it again" TTS, stop, help panel, keypad → `ACTION_DIAL`, footer, **separate Easy task log** (30 entries, no chat session).
- [ ] Easy history: cards, detail, "edit this request" refills the task sheet.
- [ ] Kid home: 6 tiles via catalogue launches, boop phrases, stars, timer, PIN gate (hashed), grown-up entry to Settings.
- [ ] Power home: command bar, `/batch` inline, `/replay`, `/logs`, recent 5.
- [ ] Social home: last-6 feed, show/hide failures, counters, share via `Intent.createChooser`, replay, new chat per action.
- [ ] Haptics + `tactile`; three appearance modes + dynamic colour; visual styles per profile.
- [ ] Evidence: one screenshot and one action per home; Easy log entry appears after a task; Kid PIN blocks Settings.

### A11. Feature screens and settings (18 d)

- [ ] Chats sheet: search, date groups, new chat, **rename**, delete via long-press and swipe, delete-all.
- [ ] Activity: status, last run, week-in-review image (Compose → Bitmap → FileProvider), recent actions.
- [ ] Runs: filters (all/payments/failed), detail with receipt, replay with filmstrip, batch, clear.
- [ ] Usage: counters from `run_records`.
- [ ] Plans: repeated-goal suggestions (≥2, 4–90 chars, max 3), intervals, list/delete; **decision**: in-process copy or WorkManager (see §13).
- [ ] Capabilities hub: readiness + tiles.
- [ ] Launchpad: **new Android package catalogue**, apps/sites segments, search, verified/unverified, `PackageManager` launch with explicit intents.
- [ ] Browser: WebView https-only, JS read/click/type, 20 000-char cap, in-app address bar.
- [ ] Memory and Skills: add/delete/clear/export; skill use.
- [ ] Device control page: bridge vs on-device states, both setup flows, retry, "cannot act" honesty.
- [ ] Settings: profile, agent switches (including `notifyAnswers`), appearance, phone access, model, character (tone/chattiness/voice/preview), parent PIN, bridge wizard (adb + pair), logs, live screen, self-check, developer, test notification, about, export, license, welcome.
- [ ] Fix the three Settings fall-through rows; do not build Models/Source.
- [ ] Inbound share target (text/image/file, max 1) + `ACTION_PROCESS_TEXT` → pending goal in the composer.
- [ ] MCP page (static, Android-accurate), License page.
- [ ] Evidence: per-screen assertion (see §8), not just "opens".

### A12. Voice, background, notifications (7 d)

- [ ] `AudioRecord` 16 kHz mono → WAV → `/transcribe`; dictation inserts text only.
- [ ] `/speak` playback; TTS fallback without a bridge; 600-char cap.
- [ ] Foreground service `shortService` for a bounded run; ongoing notification id 1001 with a tap that opens the run; stop cancels the loop.
- [ ] Notification permission denied path; test-notification action.
- [ ] 120 s run bound with a clear message.
- [ ] Tests: WAV header, empty recording, permission denied, screen-off run, notification tap.
- [ ] Evidence: screen-off run completes or stops cleanly; bridge path needs no FGS (state that in the artifact).

### A13. Evaluation, hardening, release (9 d)

- [ ] `services/evals`: task `platform` field, Android bundle map, one Android task through the adb bridge.
- [ ] `tools/scripts/build-app-catalog.py`: platform field + Android target; regenerate the Android catalogue.
- [ ] Launch-config hooks for automation (provider/endpoint/model/key/bridge URL/token) as `adb`-set extras, documented.
- [ ] Emulator E2E per path; device E2E ("open Douyin and tell me what you see") on a real Android phone.
- [ ] Conformance green on JVM and on-device.
- [ ] Play policy note (accessibility + `<queries>` + FGS type); privacy note updated with what is captured.
- [ ] Signing: release keystore out of git, `keystore.properties` ignored; APK checksum.
- [ ] Release checklist for Android in `operations/release.md`; release note in `project/releases/`.
- [ ] Evidence: signed APK on a clean phone; E2E report; policy note.

### A14. Cross-path QA and parity sign-off (10 d)

- [ ] Run the A9/A10/A11 acceptance **twice**: bridge path and accessibility path (where the emulator/device allows).
- [ ] Action-kind matrix executed on both paths; unsupported kinds assert an honest failure.
- [ ] Resurrection/tombstone, token rotation during sync, bridge death mid-run, accessibility revocation mid-run.
- [ ] Performance: cold start, chat scroll with 300 messages, observation latency, 10-step run duration.
- [ ] Parity checklist against §4.1 signed off screen by screen; defects from §4.3 confirmed absent.
- [ ] Evidence: `docs/project/evidence/A14-parity.md` with the table and links to artifacts.

---

## 7. What this plan changes outside `apps/android`

| Work | Where | Phase |
|---|---|---|
| Extend `DevicePort` with `screenshot`/`apps`, add `/apps`, update `HarmonyDevice` | `services/bridge` | A5 |
| `adb` transport, Android adapter, pool factory, role detection | `services/bridge` | A5 |
| CLI `--platform`, `/health` platform, OpenAPI `platform` | `services/bridge`, contracts | A5 |
| Evals `platform` + Android bundle map | `services/evals` | A13 |
| Catalogue generator platform field | `tools/scripts` | A13 |
| Docs: `platform-matrix.md` hash-chain claim, `apps/android/README.md` "thin client" contradiction, umbrella plan R9 | docs | A0 |

## 8. Acceptance: assertions, not "opens"

| Area | Assertion | Artifact |
|---|---|---|
| Core loop | a stub turn produces the expected outcomes, answer and record chain | JVM test output |
| Conformance | all six fixtures pass; a mutated rule fails by fixture name | CI log |
| Gate | payment screen → `classification: payment`, `approved: false`, `executed: false`; approval → executed | test log |
| Records | tamper one field → `verifyChain` fails | test log |
| Bridge | forced 401 → both bridge and sync end on the new token; non-ASCII typing case; unreachable mid-run keeps local state | transcript + test |
| Adb tap | before/after screen text differs after the tap; screenshot is a valid JPEG | artifact |
| Accessibility | observation equals the bridge-path observation for the fixture screen (refs + hash); `FLAG_SECURE` yields an honest failure | artifact |
| Sync | delete on A, edit on B, sync → deleted stays deleted; failure keeps local | two-device transcript |
| Chat | send via hardware Enter and IME Send; Shift+Enter newline; mic fills only | screenshots |
| Approval | rotate the device while the sheet is open → still pending, then allow; kill the process → denied | video/log |
| Runs | after a run, the record appears; replay advances; receipt copies | screenshot |
| Plans | a scheduled run fires while the app is alive (or WorkManager path if chosen) | log |
| Launchpad | resolved activity launches; `foreground` confirms the package | transcript |
| Voice | empty recording → "didn't catch that", nothing sent; screen-off run survives | log |
| Release | signed APK installs on a clean phone; checksum recorded | APK + hash |

## 9. Testing

JVM (core/data), Robolectric (data/UI logic), Compose UI tests (chat/approval),
emulator E2E per path, one real device per path, conformance on JVM + device,
evals task through the bridge. CI: Gradle job on every PR; emulator nightly.

## 10. Risks (expanded)

| Risk | Mitigation |
|---|---|
| `uiautomator dump` idle-state failures on video/spinners | capture via instrumentation helper or screenshot+OCR fallback; retry is not enough |
| `input text` is ASCII-only | ADBKeyboard IME flow with a setup screen, or accessibility fallback |
| `am start -n` fails for third-party apps | `resolve-activity`/`monkey -p`, assert foreground |
| Cleartext blocked at target 35 | private-range network-security-config, proven |
| Package visibility | `<queries>`; no `QUERY_ALL_PACKAGES` |
| FGS type on API 34 | `shortService` + notification + rationale; no `dataSync` abuse |
| `takeScreenshot` null on FLAG_SECURE | honest failure + tree-only mode |
| Accessibility revoked mid-run | re-check per action, fail closed |
| OEM battery killers | battery-optimisation prompt + doc; test on one OEM device |
| Run dies with the process | service-owned run + persisted pending approvals; 120 s bound |
| Token rotation breaks sync | one token holder, Authenticator, refresh sink |
| Delete resurrection | persisted tombstones on every path, delete-all |
| Image paths leak | ids only, FileProvider for display |
| Two loops diverge | conformance fixtures gate behaviour changes |
| Prompt contradiction (web) | one policy: browser allowed when network is on; prompt and router agree |
| Plaintext secrets | Keystore only; hashed PIN; no secrets in logs/export |
| Kid mode per-device | documented, not claimed otherwise |

## 11. Definition of done

- [ ] All phases A0–A14 gates passed with artifacts.
- [ ] Both execution paths pass the same action matrix and the same conformance.
- [ ] A full turn works offline (accessibility) and through the bridge.
- [ ] Sync survives deletion, rotation and failure as asserted in §8.
- [ ] No plaintext secret; no screen text or screenshot in logs.
- [ ] Signed APK + release note + policy/privacy notes.
- [ ] Docs updated to what shipped; parity checklist signed.

## 12. Effort (v2, developer-days)

| Phase | Days | Depends on |
|---|---|---|
| A0 | 5 | — |
| A1 | 5 | A0 |
| A2 | 10 | A1 |
| A3 | 8 | A1, A2 |
| A4 | 6 | A2, A3 |
| A5 | 10 | A0 (separate developer) |
| A6 | 7 | A4, A5 |
| A7 | 16 | A3, A4 |
| A8 | 10 | A1 |
| A9 | 14 | A2, A3, A4, A8 |
| A10 | 8 | A9 |
| A11 | 18 | A9 |
| A12 | 7 | A4, A6, A7 |
| A13 | 9 | A5…A12 |
| A14 | 10 | A9…A13 |
| **Total** | **143** | |

Range 130–150 depending on the accessibility surface and Play ambitions. One
developer: ~28–30 weeks. Two developers (one on A5/A13 tooling): ~16–18 weeks,
because A9 → A10/A11 is a serial UI chain. Four phases are parallelizable:
A5 with A2–A4, A10 with A11, A13 tooling with A11, A14 last.

## 13. Open decisions

- [ ] Distribution: sideload only for v1 vs Play with an accessibility declaration (A7/A13).
- [ ] Plans: in-process copy vs WorkManager (A11).
- [ ] Browser: full automation vs read-only until the JS bridge is proven (A11).
- [ ] Kid mode: per-device only vs synced setting (A11).
- [ ] FGS type and notification copy approved by whoever ships (A0/A12).
- [ ] Windows client: shared Kotlin core vs its own stack (not this plan).
