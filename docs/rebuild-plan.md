# HOPA rebuild plan and roadmap

**This document is the contract.** Development is finished when every checkbox in
§5–§15 is checked, `python scripts/plan-status.py --require-complete` exits `0`,
and the two sign-offs in §15 are recorded.

Reference product: Mika (Apache-2.0). HOPA keeps its own name, UI and NOTICE.

---

## 1. How to use this document

### 1.1 Checkbox rules

- `- [ ]` = not done. `- [x]` = done **with evidence**.
- Never tick a box without evidence appended on the same line:
  `(evidence: docs/bench-v1.md#run-2026-12-01)` or `(evidence: PR #42)` or
  `(evidence: device screenshot IMG_0042)`.
- A box is not done because code was written. It is done when the stated
  verification passes on the stated target (emulator, phone, CI).
- Blocked work stays unchecked and gets a `[BLOCKED: reason]` prefix.
- Decision boxes come in pairs. Exactly one of the pair must be checked. The
  unchecked sibling counts as **decided**, not as remaining work, and
  `plan-status.py` excludes it from the finish gate.
- Conditional work ("if approved…", "if needed…") is prose, not a checkbox.
  Once a branch is approved it becomes its own gated plan with its own boxes.
- Do not add checkboxes casually. Every box must be verifiable by a third party.
- Box size is not uniform: one box may be an hour or a two-week epic. The
  percentage is a count, not a schedule. Exit criteria, not the count, decide a
  milestone.
- `python scripts/plan-status.py --lint` must pass: no duplicate boxes, every
  `[x]` carries `(evidence: …)`, and no decision pair is double-checked.

### 1.2 Progress

```bash
python scripts/plan-status.py                 # per-phase table
python scripts/plan-status.py --lint          # check evidence, duplicates, decision pairs
python scripts/plan-status.py --require-complete   # exit 1 until finished
```

### 1.3 Milestones

| Milestone | Phases | Meaning |
|---|---|---|
| M0 | 0 | Foundations: CI green, decisions recorded, baseline measured |
| M1 | 1 | PC harness closes the observe→act→verify loop on 5 tasks |
| M2 | 2 | Mika brain runs HOPA's body; 20-task bench published |
| M3 | 3 | ArkTS core reaches parity with the JVM brain |
| M4 | 4 | On-device control works without a PC (or fallback signed) |
| M5 | 5 | Safety and privacy suites pass; payment gate is unbypassable |
| M6 | 6–8 | Usable app, evaluated, signed, released |

### 1.4 Estimates

4–6 people, 4–6 months to MVP; 9–12 months to near-parity. Phase 4 and Phase 7
run in parallel with Phase 3. The critical path is **ACL approval → on-device
a11y → M4**. Everything before M4 must not depend on the ACL.

M3 proves the on-device loop on **ArkWeb surfaces** (no ACL needed). Driving
other apps on-device still needs the accessibility ACL, so M3 alone does not
satisfy M4. Do not let M3's "runs with no PC" claim hide that dependency.

Cross-cutting work in §5.5, §6.8, §7.9, §8.6, §9.7, §10.6, §11.3, §12.3 and
§13.3 is not a separate phase. It lands inside the phase that owns it and is
counted there. Appendix E must be resolved before the milestone that depends on
it, not at the end.

---

## 2. Scope

### 2.1 In scope

- A GUI agent that operates HarmonyOS apps and websites: read screen, tap, type,
  scroll, navigate, verify.
- App routing: name / alias / domain → app; unknown installed app still operable.
- Skills, memory, learned app notes.
- WASM sandbox for user scripts (Pyodide + QuickJS), offline by default.
- Payment and irreversible actions gated, fail-closed.
- PC-tethered mode (`hdc` + `uitest`) for development, bench and enterprise.
- Standalone on-device mode when the accessibility ACL is approved.

### 2.2 Out of scope (never)

- Hidden second screen / virtual display for a normal app.
- `proot`, Linux userland, `apt`, native binaries on device.
- ADB self-connection, uid 2000 shell helper, Android hidden APIs.
- Running Android APKs.
- Copying Mika's name, UI assets or GPL components.

### 2.3 Non-negotiables

- One execution path: every action passes `ActionExecutor`.
- Payment is fail-closed and never remembered.
- Append-only run records.
- No secrets in logs or git.
- The README states plainly that there is no background screen.
- No Python runtime in the HAP. Pyodide, if ever enabled, is WASM inside a web page, not the app runtime.

---

## 3. Current state (audited 2026-11-05)

| Area | State | Evidence |
|---|---|---|
| Repo | 2 commits, public, Apache-2.0 | `git log` |
| `app/core` | action gate, approval policy, tool registry, types, model interface; unit tests | `app/core/src` |
| `app/capabilities` | interfaces + stubs; a11y extension empty and not declared | `module.json5`, `AccessibilityExtension.ets` |
| `app/entry` | 4-tab ArkUI shell; chat says “agent loop placeholder” | `pages/Index.ets` |
| Agent loop | asks model for one action; never observes the screen | `AgentLoop.ets` |
| `pc-agent` | CLI + MCP implemented: devices, dump, tap, double-tap, long-press, type, swipe, screenshot, launch, stop, key, install, uninstall | `pc-agent/src` |
| `bench` | 20 task files valid (5 device-confirmed), runner, stub model, CLI | `bench/tasks` |
| Brain | Kotlin router + HTTP service (34 assertions + schema contract) | `brain/src`, `docs/brain.md` |
| Knowledge | none: 0 `APP.md`, 0 sites, 0 skills | — |
| CI | Python tests + ruff; HAP build and core Local Tests skip with a warning when the mirrored toolchain secret is absent | `.github/workflows/ci.yml` |
| Tests baseline | 228 Python tests pass in a combined run (pc-agent, bench, agent, plan tooling), agent coverage 90%, 20 bench task files validate; ArkTS tests not run here | local run 2026-11-05 |

Known gaps to close first:

- `AgentLoop` has no observation input.
- `ApprovalPolicy` treats `ui.tap` as safe, so a tap on “Pay” is auto-approved.
- The model payload can set `isPayment`, which contradicts the doc.
- No app routing, no knowledge, no skills, no memory.
- No device matrix, no baseline numbers, no evidence log.

---

## 4. Target architecture

```
ArkUI entry (chat / tasks / settings / memory / takeover / approval)
        │
core/  AgentLoop ── ModelClient (OpenAI-compatible)
        │
        └── ActionExecutor        ← the only execution path
              guards → approval → execute → verify → record
                       │
        capabilities/  a11y | web | sandbox | system
                       │
              HarmonyOS device

Brain host:
  M1–M2: local JVM service (Mika core), HTTP / MCP
  M3+:   ArkTS core on device, same contract, golden-file parity

Harness: pc-agent (hdc + uitest) + HOPA-Bench
```

Module responsibilities:

| Module | Owns | Must not |
|---|---|---|
| `core/` | loop, gate, routing, memory, records | import UI or platform APIs |
| `capabilities/*` | one platform surface each | import each other |
| `entry/` | UI, permissions, wiring | contain agent logic |
| `pc-agent/` | device I/O for development | be required at runtime |
| `bench/` | tasks, runner, scoring | be imported by the app |

---

## 5. Phase 0 — Foundations (1–2 weeks)

### 5.1 Repository and process

- [x] Mark `docs/roadmap.md` as superseded and link this plan (evidence: docs/roadmap.md)
- [x] Link this plan from `README.md` (evidence: README.md)
- [x] Add `docs/adr/` with an ADR template (evidence: docs/adr/README.md)
- [x] ADR-0001: brain hosting (remote JVM first, ArkTS later) (evidence: docs/adr/0001-brain-hosting.md)
- [x] ADR-0002: knowledge format and HarmonyOS bundle mapping (evidence: docs/adr/0002-knowledge-format.md)
- [x] ADR-0003: sandbox runtime (Pyodide + QuickJS, no Linux) (evidence: docs/adr/0003-sandbox-runtime.md)
- [x] ADR-0004: ACL strategy and foreground fallback (evidence: docs/adr/0004-acl-strategy.md)
- [x] ADR-0005: PC-tethered vs standalone product split (evidence: docs/adr/0005-pc-tethered-vs-standalone.md)
- [x] ADR-0006: model provider, budget and cost target per task (evidence: docs/adr/0006-model-provider-and-budget.md)
- [ ] File the accessibility ACL request in week 1; record ticket, date and contact (critical path)
- [x] Add `CONTRIBUTING.md` with the evidence rule from §1.1 (evidence: CONTRIBUTING.md)
- [x] Add `CODEOWNERS` (evidence: CODEOWNERS)
- [x] Add PR template with the phase checklist (evidence: .github/PULL_REQUEST_TEMPLATE.md)
- [ ] Enable branch protection on `main`; require CI
- [x] Add issue labels: `phase/0..9`, `area/core|cap|ui|bench|docs`, `risk` (evidence: phase/*, area/*, risk labels created)
- [ ] Create the project board with phases 0–9
- [ ] Assign an owner per phase
- [x] Write a definition of ready for starting a phase (evidence: docs/definition-of-ready.md)
- [ ] Schedule a monthly risk review
- [x] Add a decision log index under `docs/adr/` (evidence: docs/adr/README.md)
- [x] Pin toolchain versions in `docs/setup.md`: Python 3.12, Node LTS, DevEco 26, compileSdk 26, minCompatible 6.1.1 (API 24), CLT 26.0.0.851 (evidence: docs/setup.md)
- [x] Add `.editorconfig` and formatting rules for ArkTS and Python (evidence: .editorconfig)
- [x] Add `scripts/plan-status.py` and test it (evidence: table, --json, --lint, --require-complete, --list-unchecked, decision pairs)
- [x] Add a CI job that prints plan progress and runs `plan-status.py --lint` on every PR (evidence: .github/workflows/ci.yml)

### 5.2 CI and quality gates

- [x] `ruff check` green on `pc-agent` and `bench` (evidence: CI run 42094448015)
- [x] `ruff format --check` green (evidence: CI: ruff format --check)
- [x] `pytest pc-agent` green (evidence: CI run 42094448015)
- [x] `pytest bench` green (evidence: CI run 42094448015)
- [x] `hopa_bench validate --tasks bench/tasks` green (evidence: CI run 42094448015)
- [ ] ArkTS unit tests run on a macOS runner
- [ ] HAP build runs on Linux with a mirrored CLT archive
- [ ] CI fails (not skips) when `HARMONY_CLI_TOOLS_URL` is missing on `main`
- [x] Coverage report for Python; threshold set (evidence: CI: pytest agent --cov --cov-fail-under=80 (89%))
- [ ] Coverage report for ArkTS; threshold set
- [ ] `pip-audit` / Dependabot enabled
- [ ] License check: Apache-2.0, NOTICE current, no GPL
- [ ] Secret scan (gitleaks) in CI

### 5.3 Environment and baseline

- [ ] Record the device matrix: emulator + one physical HarmonyOS 6+ phone
- [ ] `hdc list targets` works for both
- [ ] `pc-agent devices` works for both
- [ ] `pc-agent dump` returns a parseable layout on both
- [ ] `pc-agent screenshot` works on both
- [x] Baseline test run recorded in `docs/baseline.md` (counts, failures) (evidence: docs/baseline.md (local run 2026-11-05; device pending))
- [ ] Baseline bench run recorded (5 tasks, pass/fail, latency)
- [ ] Model provider chosen and key stored in env, not git
- [ ] Model latency and cost measured for one call
- [x] Write `docs/status.md` with the honest one-paragraph state (evidence: docs/status.md)

### 5.4 Exit criteria (M0)

- [x] CI is green on `main` (evidence: CI run 42094448015; HAP and ArkTS jobs skipped)
- [x] All six ADRs merged (evidence: docs/adr/ (six ADRs))
- [ ] Baseline numbers exist and are reproducible
- [x] `plan-status.py` reports the starting count (evidence: 767 total, 3 done, 0 lint errors)

### 5.5 Programme, people and change control

- [x] Named owner for every phase (not “TBD”) (evidence: docs/owners.md)
- [ ] Named reviewer for core, capabilities, bench and docs
- [x] Team skills matrix: ArkTS, Kotlin/JVM, Python, HarmonyOS a11y, security (evidence: docs/owners.md (skills matrix))
- [x] Hiring or contracting gap identified for any missing skill (evidence: docs/owners.md (hiring gap))
- [ ] Two-week budget approved for model calls and devices
- [x] Dependency list with owners and lead times (ACL, device, toolchain, store) (evidence: docs/owners.md (dependencies))
- [x] Assumption register started (Appendix E) (evidence: Appendix E)
- [x] Open-questions register started (Appendix E) (evidence: Appendix E)
- [x] Change-control rule: plan edits need a PR and a one-line reason (evidence: CONTRIBUTING.md (pull requests))
- [x] Definition of done for a PR (tests, docs, evidence, review) (evidence: .github/PULL_REQUEST_TEMPLATE.md)
- [x] Branching and commit-message convention written down (evidence: CONTRIBUTING.md)
- [x] Semantic-versioning policy written down (evidence: docs/versioning.md)
- [x] Documentation ownership map: who updates which page (evidence: docs/owners.md (documentation ownership))
- [x] One-page architecture overview diagram committed (evidence: docs/architecture.md)
- [x] Glossary of HOPA, Mika, ACL, a11y, observation, capability (evidence: docs/glossary.md)
- [ ] Weekly 15-minute progress review using `plan-status.py`
- [ ] Plan totals and phase estimates re-baselined after this audit
- [ ] Decide how a managed / MDM device differs from a personal device, and whether HOPA supports it
- [ ] Budget approved for a device farm or a second physical phone for nightly runs
- [x] Offboarding note: where secrets, keys and accounts live (evidence: docs/owners.md (offboarding))

---

## 6. Phase 1 — Harness and closed loop (2–3 weeks)

### 6.1 Observation contract

- [x] Define `Observation` JSON schema: `tree`, `text`, `focus`, `screenSize`, `screenshotRef`, `timestamp`, `hash` (evidence: schemas/observation.schema.json)
- [x] Add `$schema` files under `schemas/` (evidence: schemas/)
- [x] `hopa-agent observe` emits the schema (evidence: agent/src/hopa_agent/cli.py)
- [x] `hopa-agent observe --screenshot` attaches an image reference (evidence: agent/src/hopa_agent/capture.py)
- [x] Layout parser extracts `id`, `text`, `type`, `bounds`, `clickable`, `enabled`, `checked`, `scrollable` (evidence: agent/src/hopa_agent/observation.py)
- [x] Stable element refs per observation (`e1`, `e2`, …) mapped to nodes (evidence: agent/tests/test_observation.py)
- [x] Deterministic ref assignment: two identical trees produce identical refs; refs still expire on the next observation (evidence: agent/tests/test_observation.py)
- [x] Redaction pass for phone numbers, emails, OTPs, card numbers (evidence: agent/src/hopa_agent/observation.py)
- [x] Redaction unit tests (20 cases) (evidence: agent/tests/test_observation.py (20 cases))
- [x] Observation hash for dedupe (evidence: agent/src/hopa_agent/observation.py)
- [x] Large-tree truncation rule (cap nodes, keep focus path) (evidence: agent/src/hopa_agent/observation.py)
- [ ] Coordinate transform between layout bounds and device pixels (density, rotation)
- [x] Record the active window id and display id (evidence: Observation.to_dict)
- [x] Refs are scoped to one observation; records store the observation hash and refs are audit-only (evidence: RunRecord.observationHash)
- [ ] Screenshot format, resolution and size budget defined
- [x] `docs/contracts/observation.md` (evidence: docs/contracts/observation.md)

### 6.2 Action contract

- [x] Define `Action` JSON schema: `kind`, `ref`, `text`, `x`, `y`, `toX`, `toY`, `app`, `url`, `timeoutMs` (evidence: schemas/action.schema.json)
- [x] Kinds: `ui.observe`, `ui.tap`, `ui.doubleTap`, `ui.longPress`, `ui.type`, `ui.swipe`, `ui.scroll`, `ui.back`, `ui.home`, `ui.launch`, `ui.stop`, `ui.wait` (evidence: agent/src/hopa_agent/actions.py)
- [x] Kinds: `web.navigate`, `web.read`, `web.click`, `web.type` (evidence: agent/src/hopa_agent/actions.py)
- [x] Kinds: `system.setAlarm`, `system.addEvent`, `system.openLink`, `system.share` (evidence: agent/src/hopa_agent/actions.py)
- [x] Kinds: `sandbox.run` (evidence: agent/src/hopa_agent/actions.py)
- [x] Coordinate fallback when no ref exists (evidence: DeviceExecutor._point)
- [x] Action validation rejects unknown kinds (fail-closed) (evidence: agent/tests/test_actions.py)
- [x] Every action returns before/after observations (evidence: Outcome.before/after)
- [ ] Per-action timeout and one bounded retry
- [x] `docs/contracts/action.md` (evidence: docs/contracts/action.md)

### 6.3 Loop

- [x] `AgentLoop` sends system prompt + goal + current observation (evidence: agent/src/hopa_agent/models.py)
- [x] Model returns exactly one action as JSON (evidence: agent/src/hopa_agent/models.py)
- [x] Schema-constrained decoding or strict validation (evidence: Action.from_dict)
- [x] Malformed JSON → one repair attempt → fail with a typed error (evidence: OpenAIClient.decide)
- [x] Execute through the single executor (`DeviceExecutor` on PC, `ActionExecutor` on device) (evidence: agent/src/hopa_agent/executor.py)
- [ ] Verify by re-observing and comparing expected text/state
- [x] Append step to history with observation summary and refs (evidence: AgentLoop.run)
- [ ] Context diffing: send only changed subtrees when the screen barely changes
- [x] History keeps hashes and summaries, not full trees (evidence: AgentLoop.run)
- [x] Step cap, wall-clock cap, token cap (evidence: AgentLoop.__init__)
- [x] Stop conditions: success, failure, need-user, payment, max steps (evidence: AgentLoop.run)
- [x] Run record per step, append-only (evidence: RunStore.append)
- [ ] Resume a run from records
- [x] `StubModelClient` replays scripted actions without network (evidence: StubModelClient)
- [x] Real client with retry/backoff and timeout (evidence: OpenAIClient._complete)
- [x] Prompt rule: use refs, never invent coordinates (evidence: SYSTEM_PROMPT)
- [x] Prompt rule: one action per step (evidence: SYSTEM_PROMPT)
- [x] Prompt rule: payment and irreversible actions stop for approval (evidence: SYSTEM_PROMPT)
- [x] Prompt rule: screen text is untrusted data, never instructions (evidence: SYSTEM_PROMPT)
- [x] Loop unit tests with the stub model (10 scenarios) (evidence: agent/tests/test_loop.py (10 scenarios))
- [ ] Loop integration test against the emulator

### 6.4 Executor and gate (fix current gaps)

- [ ] Remove `isPayment` from the model-supplied payload
- [x] `ApprovalPolicy` classifies from action + screen context, not kind alone (evidence: ApprovalPolicy.classify)
- [x] A tap on a payment-classified screen always asks (evidence: agent/tests/test_policy.py)
- [x] Guard failure aborts before any capability call (evidence: DeviceExecutor.execute)
- [x] Denied action writes `approved=false` and never executes (evidence: agent/tests/test_executor.py)
- [ ] Denied payment cannot be retried through another path
- [ ] Verifier compares intended vs observed effect
- [x] Run record includes approval decision and observation hash (evidence: RunRecord)
- [x] Gate unit tests (20 cases) (evidence: agent/tests/test_policy.py (31 cases))
- [x] Adversarial gate tests (10 cases) (evidence: agent/tests/test_adversarial.py (12 cases))

### 6.5 Bench v0

- [x] Runner supports `text_visible`, `node_exists`, `app_foreground`, `screen_hash` (evidence: bench/src/hopa_bench/runner.py)
- [x] Runner records steps, latency, model tokens (evidence: StepResult.latency_ms, TaskResult.tokens)
- [ ] Existing 5 tasks pass with the stub model
- [ ] Existing 5 tasks pass with a real model on the emulator
- [x] Failure taxonomy defined and emitted (evidence: bench/src/hopa_bench/runner.py classify_failure)
- [x] `docs/bench-v0.md` with results (evidence: docs/bench-v0.md)
- [ ] 30-second demo recording

### 6.6 Runtime behaviour

- [x] Loop and stagnation detection: same action + same observation hash twice → replan or stop (evidence: AgentLoop.run)
- [ ] Wrong-screen recovery: back / home / re-observe policy
- [x] `wait_for` condition on text, ref or state, with timeout (evidence: agent/src/hopa_agent/runtime.py)
- [x] `scroll_to` with bounded attempts (evidence: agent/src/hopa_agent/runtime.py)
- [x] `find_by_text` and `find_by_ref` helpers (evidence: Observation.find_text/find_ref)
- [x] `ask_user` tool with structured options (evidence: ModelDecision.options + agent/tests/test_loop.py)
- [x] `say` final-answer tool (evidence: ModelDecision.say + RunResult.say)
- [ ] `stop` tool with a reason
- [ ] `handover` tool for login, 2FA, CAPTCHA and payment
- [ ] Cancel mid-step leaves the app in a safe state
- [x] Duplicate-tap guard (idempotency by ref + action hash) (evidence: DeviceExecutor._last_key)
- [ ] Popup handling: cookie banners, rating prompts, update dialogs, ads
- [ ] System permission dialog handling policy (grant only what the task needs)
- [x] Timeout and backoff policy documented (evidence: docs/contracts/errors.md)
- [ ] Step and cost budgets per task
- [x] Emergency-number guard: never dial 110 / 112 / 119 / 999 or any local emergency number; hand over (evidence: ApprovalPolicy.is_emergency_call)
- [ ] Unicode, emoji and RTL input tested
- [ ] Screen-off and lock-during-task detection; pause safely instead of tapping blind
- [ ] Low-battery policy: pause long tasks below a threshold
- [ ] Thermal-throttling detection with a graceful slowdown
- [ ] Do Not Disturb and driving-mode detection
- [ ] Coexistence with other accessibility or automation services: never two drivers at once
- [ ] Tests for every runtime behaviour above

### 6.7 Exit criteria (M1)

- [ ] 5/5 bench tasks pass with the real model
- [ ] Every step has a run record
- [ ] No new device permissions required
- [ ] `AgentLoop` never acts without a fresh observation
- [ ] Payment tap is blocked in a manual test

### 6.8 Protocol, telemetry and errors

- [x] Version the brain↔body contract (`v1`) and record it in the schema (evidence: Observation.schemaVersion)
- [x] Compatibility rule: body rejects an unknown major version, accepts a newer minor (evidence: docs/contracts/observation.md)
- [x] Error-code taxonomy: `E_MODEL`, `E_SCHEMA`, `E_ACTION`, `E_CAPABILITY`, `E_POLICY`, `E_DEVICE` (evidence: agent/src/hopa_agent/errors.py)
- [x] Every error carries a retryable flag and a user-facing message key (evidence: agent/src/hopa_agent/errors.py)
- [ ] Trace id propagated from UI → loop → brain → model → device
- [ ] Clock-skew tolerance for timestamps from the device and the PC
- [x] Message-size limit with tree truncation and compression (evidence: observation.truncate + models._messages)
- [x] Schema-evolution rules: additive fields only within a major version (evidence: docs/versioning.md)
- [ ] Golden contract fixtures shared by JVM, ArkTS and `pc-agent`
- [ ] Contract tests run in CI for all three implementations
- [x] Local structured log with rotation and redaction (evidence: agent/src/hopa_agent/logging.py + tests)
- [ ] Optional opt-in diagnostic bundle export

---

## 7. Phase 2 — Mika brain on HOPA body (4–6 weeks)

> Target: reuse Mika's pure-Kotlin core as the brain, for speed and fidelity.
> The body stays HOPA. Nothing Android-specific is copied.

### 7.1 Brain service

- [ ] Extract the ported Mika subset (Appendix A.2 and A.2b) into a standalone JVM module with zero `android.*` imports
- [x] Verify with `grep -r "android\."` returning nothing in the ported module (evidence: grep -r "android\." brain/src returns nothing)
- [x] Build with JDK 17; pin the toolchain (evidence: scripts/brain.ps1 / brain.sh (Kotlin 2.1.0, JDK 17))
- [x] HTTP API `POST /decide`: `{goal, observation, history, settings}` → `{action, say, done}` (evidence: brain/src/main/kotlin/hopa/brain/Server.kt + ServerTest)
- [x] Sticky session id for multi-step tasks (evidence: BrainService.sessions + GET /session/{id})
- [x] Health and version endpoints (evidence: ServerTest health/version)
- [x] Structured logs with trace id (evidence: X-Trace-Id + JSON stderr log)
- [x] Contract tests against the JSON schema (evidence: scripts/brain-contract.py validates decision.schema.json)
- [x] No network except the model endpoint (evidence: brain/src has no outbound HTTP client)
- [ ] Dockerfile for repeatable local runs
- [ ] `NOTICE` lists every Mika file reused
- [x] `docs/port-log.md` started (evidence: docs/port-log.md)

### 7.2 Knowledge port

- [ ] Copy the knowledge schema and loader
- [ ] Inventory Mika's 23 apps and 18 sites; mark Android-only fields
- [ ] Triage the 23 apps: available on HarmonyOS, web-only, or absent; record the evidence
- [ ] Build the HarmonyOS bundle map from `hdc shell bm dump -a`
- [ ] Rewrite `APP.md` for the 10 highest-value apps that exist on HarmonyOS
- [ ] Rewrite `APP.md` for the remaining HarmonyOS-available apps; drop absent apps with a written note
- [ ] Rewrite `SITE.md` for 18 sites (domains mostly reusable)
- [ ] Add 12 HarmonyOS system apps: Settings, Clock, Calendar, Contacts, Notepad, Files, Camera, Gallery, Browser, AppGallery, Petal Maps, Music
- [ ] Add `pace: careful` to every irreversible app path
- [ ] Add `packageAliases` for HarmonyOS bundles
- [ ] Front-matter parser validates all files
- [ ] Loader unit tests
- [ ] `knowledge_search` returns HarmonyOS entries only
- [ ] `docs/knowledge.md` explains the format and how to add an app

### 7.3 Routing

- [x] Port `KnowledgeStore.matchTask` (lexical, installed-first, word boundaries) (evidence: brain/src/main/kotlin/hopa/brain/Router.kt + RouterTest)
- [x] Port `ChannelAdvisor` (app vs web vs signed-in) (evidence: brain/src/main/kotlin/hopa/brain/Router.kt + RouterTest)
- [ ] Port `GuideCatalog` and the skills index
- [x] Port `packageFor` (evidence: brain/src/main/kotlin/hopa/brain/Router.kt + RouterTest)
- [x] Add installed-app listing: `pc-agent apps` → `{bundle, label}` (evidence: pc-agent/src/hopa_pc_agent/apps.py + tests)
- [ ] Unknown app: list → label → launch → generic operation
- [ ] Ambiguous match → ask the user once, remember the answer
- [x] Routing tests: known app, alias, domain, unknown, two plausible (evidence: brain/src/test/kotlin/hopa/brain/RouterTest.kt (17 assertions))
- [x] Routing tests: generic words never match (`app`, `web`, `site`) (evidence: brain/src/test/kotlin/hopa/brain/RouterTest.kt)
- [ ] Bench: open 5 apps by name
- [ ] Bench: operate a freshly installed unknown app
- [x] Document the honest limit: lexical, not embeddings; no auto-learning for unknown apps (evidence: docs/port-log.md (honest limits))
- [ ] Pinyin and English aliases for Chinese app names
- [ ] Locale-aware matching for zh-CN and en-US
- [ ] App-not-installed detection in routing, with an install option

### 7.4 Prompts and skills

- [ ] Port 118 prompts; strip Android-only tool names
- [ ] Port `intent_gate` (DISCUSS / READ / ACT)
- [ ] Port `channels.md` decision order
- [ ] Port `roles/app_knowledge*.md`
- [ ] Port 6 skills (9 files: manifests, references and the PDF script) and validate manifests
- [ ] Port personal skill creation
- [ ] Port the app-notes draft → trial → verified flow
- [ ] Prompt size budget and truncation rules
- [ ] Token accounting per step
- [ ] Prompt-injection tests: screen text cannot issue instructions
- [ ] Prompt snapshot tests (golden files)

### 7.5 Memory and records

- [ ] Port run records and the memory model
- [ ] Port `AppKnowledgeLearning`
- [ ] Learned notes attach only to known app entries (document this)
- [ ] Memory view data source
- [ ] Redaction before storage
- [ ] Encryption at rest or an explicit risk note
- [ ] Export and delete memory
- [ ] Memory retention policy implemented (runs, notes, screenshots)

### 7.6 Knowledge validation and maintenance

- [ ] Per-app smoke test: launch and reach one known screen for every app in the launch set (ported + system)
- [ ] `validated` version and date in every `APP.md`
- [ ] Detect app version change via `bm dump` and mark its knowledge stale
- [ ] Knowledge rollback: pin the knowledge version per release and restore the previous one
- [ ] Selectors survive text and locale changes (ids first, text second)
- [ ] Fallback when a known screen is missing
- [ ] Contribution guide: add an app in one file
- [ ] Knowledge schema and front matter validated in CI
- [ ] Track HarmonyOS vs Android divergence per app
- [ ] Record regional and locale variants
- [ ] Verify the documents skill (PDF extraction) on HarmonyOS
- [ ] Verify the transcription skill (audio → text) on HarmonyOS
- [ ] Verify the info-research skill on HarmonyOS

### 7.7 Bench v1 (20 tasks)

- [x] 20 tasks defined (Appendix B) (evidence: bench/tasks (20 valid))
- [ ] Bundle names confirmed on device
- [ ] Safety tasks included (payment refusal, deny stops, takeover)
- [ ] Three consecutive runs; variance reported
- [ ] Success, steps, p50/p95 latency, tokens, cost
- [ ] Per-app breakdown
- [ ] `docs/bench-v1.md` published
- [ ] Benchmark task, fixture and screenshot licences recorded; no third-party content copied without permission
- [ ] Regression gate with the stub model in CI

### 7.8 Exit criteria (M2)

- [ ] 20-task success rate ≥ 70%
- [ ] Payment refusal 100% on the Bench v1 safety tasks
- [ ] Unknown app operable from `list_apps`
- [ ] No Android-only dependency in the brain
- [ ] Bench report reproducible by a second person

### 7.9 Licensing and provenance

- [ ] Apache-2.0 obligations met: copyright headers kept, NOTICE updated, changes stated
- [ ] Per-file provenance manifest: Mika path, HOPA path, modified yes/no
- [ ] No GPL, AGPL or source-available code in the ported tree
- [ ] No Android hidden API, `proot`, `adb` or `VirtualDisplay` code copied
- [ ] Knowledge content licence audit: do not copy third-party app documentation
- [ ] Prompt provenance recorded; Chinese prompts translated, not silently dropped
- [ ] Mika trademarks and product names absent from HOPA UI and docs
- [ ] Legal review of the port recorded
- [ ] Third-party notices generated from the dependency tree
- [ ] Reuse decision recorded for every Mika module (port, rewrite, drop)

---

## 8. Phase 3 — ArkTS core on device (6–10 weeks)

### 8.1 Port scope and skeleton

- [ ] ADR: exactly which modules move on device
- [ ] `app/core` file layout mirrors Mika's core directories
- [ ] Shared JSON contracts package for JVM and ArkTS
- [ ] Golden-file corpus shared by both implementations
- [ ] Parity test harness defined

### 8.2 Port modules

- [ ] `Types`, `ToolRegistry`, `ActionExecutor`, `ApprovalPolicy`
- [ ] `uistate` (46 files) — screen model
- [ ] `observation`, `verify`, `record`
- [ ] `knowledge` (routing, channel, catalog)
- [ ] `agent` loop and context builder
- [ ] Decide per remaining Mika module (action, run, gate, context, prompt, settings, trigger, usage, trace, net, remote, mcp, oauth, workspace, general, assembly, selfcheck): port, rewrite or drop; record in Appendix A.2b
- [ ] `memory`, `skills`
- [ ] `model` client over `@ohos.net.http`
- [ ] Serialization without kotlinx (`@ohos.util.json` or generated codecs)
- [ ] File storage over `@ohos.file.fs`
- [ ] Secure storage over Asset Store Kit / HUKS
- [ ] Settings over `@ohos.data.preferences`
- [ ] Remove the JVM service from the decision path behind a feature flag
- [ ] Unit tests for every ported module (hypium)
- [ ] Golden-file parity: 200 cases
- [ ] Differential fuzz: 100 random tasks, same decisions
- [ ] Decision latency < 100 ms excluding the model
- [ ] `docs/port-log.md` complete

### 8.3 On-device model plumbing

- [ ] Provider settings UI and storage
- [ ] Streaming responses (or documented non-streaming)
- [ ] Timeout, retry, backoff
- [ ] Token and cost caps per task
- [ ] Offline behavior: clear error, no silent retry loop
- [ ] Model fallback list
- [ ] Key never logged

### 8.4 Model quality and context

- [ ] Prompt versioning and changelog
- [ ] Context-window management and summarization for long runs
- [ ] Determinism policy (temperature, seed) documented
- [ ] Model evaluation matrix across at least two models
- [ ] Rate-limit handling with backoff
- [ ] Cost budget enforced per task and per day
- [ ] Hallucinated-ref detection (ref not in the current observation)
- [ ] Model data-residency note for the chosen provider
- [ ] Provider safety-filter behaviour documented
- [ ] Prompt and response logging redacted
- [ ] Prompt/context caching and reuse measured and enabled where the provider supports it
- [ ] Local/offline model option evaluated and decided

### 8.5 Exit criteria (M3)

- [ ] The loop runs on device with no PC
- [ ] 200/200 parity cases pass
- [ ] All Phase 2 bench tasks run through the ArkTS core
- [ ] JVM service is optional, not required

### 8.6 ArkTS runtime engineering

- [ ] Heavy parsing runs in TaskPool or Worker, not on the UI thread
- [ ] UI-thread blocking budget measured and met (< 16 ms per frame)
- [ ] On-device memory ceiling measured under a 30-step task
- [ ] Core cold-start budget defined and measured
- [ ] Core bundle-size budget defined and met
- [ ] Exception and error conventions consistent across modules
- [ ] Logging framework with levels, trace id, rotation and redaction
- [ ] Record writes are crash-safe (temp file + atomic rename)
- [ ] Feature flag switches between JVM service and on-device core
- [ ] Rollback to the JVM service documented and tested
- [ ] Deprecation policy for internal APIs
- [ ] Long-running task survives app backgrounding per platform rules
- [ ] No `any` in ArkTS core; strict mode on
- [ ] Dependency review for every `ohpm` package

---

## 9. Phase 4 — Capabilities (6–10 weeks, parallel with Phase 3)

### 9.1 Accessibility (the product)

- [ ] Verify the exact import and signature against the API 26 SDK
- [ ] Declare the extension in `module.json5` behind a build flag
- [ ] Confirm the week-1 ACL ticket is still open and escalate before Phase 4 starts
- [ ] `onConnect` marks availability
- [ ] `onAccessibilityEvent` converts the active window into `Observation`
- [ ] Read node `id`, `text`, `type`, `bounds`, `clickable`, `enabled`
- [ ] Tap by node ref
- [ ] Type text into a focused node
- [ ] Swipe and scroll
- [ ] Global back and home
- [ ] Foreground-only guard: define and enforce when HOPA may drive
- [ ] User consent screen and live status indicator
- [ ] Tests on Settings, Clock, Calendar
- [ ] Tests on 5 third-party apps
- [ ] Empty-tree detection and unsupported-app message
- [ ] OCR fallback for missing text
- [ ] Vision fallback for custom-drawn UIs
- [ ] `CAPTURE_SCREEN` request and per-session consent
- [ ] Screenshot redaction (status bar, notifications)
- [ ] Observe latency < 300 ms
- [ ] Accessibility-event throttling and debounce (no event flood)
- [ ] Stale-ref invalidation on window or tree change; never tap a stale ref
- [ ] Gesture-conflict policy with the user and with system gestures
- [ ] `docs/a11y.md` with what works and what does not

### 9.2 Web

- [ ] ArkWeb component and `WebviewController` ownership
- [ ] `web.navigate`, `web.read`, `web.click`, `web.type`
- [ ] DOM text extraction via `runJavaScript`
- [ ] Per-task network toggle
- [ ] Download and file-picker approval
- [ ] Cookie and session isolation
- [ ] Signed-in site detection
- [ ] HTTPS allow-list for deep links
- [ ] Tests on 5 sites
- [ ] `docs/web.md`

### 9.3 System intents

- [ ] Alarm via `Want` to Clock
- [ ] Calendar event via provider APIs
- [ ] Contacts read with user grant
- [ ] Share sheet
- [ ] Open link with scheme/host allow-list
- [ ] Install/uninstall with approval
- [ ] Settings deep links
- [ ] Tests for each intent
- [ ] `docs/system.md`

### 9.4 Sandbox

- [ ] Bundle Pyodide and QuickJS in `rawfile`
- [ ] Pyodide and QuickJS artifacts are checksum-pinned on download and load
- [ ] Verify arm64 support, WASM memory limits and required features on the target devices
- [ ] Hidden ArkWeb page bridge
- [ ] Offline by default
- [ ] No device APIs exposed to scripts
- [ ] Document that the HAP ships no Python runtime; Pyodide is an optional WASM page
- [ ] CPU, memory and wall-clock limits
- [ ] Network grant per run, logged
- [ ] Python package allow-list (pure wheels only)
- [ ] QuickJS limits documented
- [ ] 10 sandbox escape tests
- [ ] Startup time measured
- [ ] Companion Linux fallback documented, not built
- [ ] `docs/sandbox.md`

### 9.5 Platform edge cases

- [ ] Secure windows (banking, DRM): detect unreadable content and hand over
- [ ] Password and OTP fields: never read or type; hand over
- [ ] IME composition for Chinese and English; autocorrect off for codes
- [ ] Rotation, resolution and density changes mid-task
- [ ] Foldable, split-screen and multi-window layouts
- [ ] Lock screen: refuse to act and ask the user to unlock
- [ ] System permission dialogs that appear during a task
- [ ] Notification shade interaction, if the API allows it
- [ ] Clipboard read and write with consent
- [ ] App cloning, private space and multi-user profiles
- [ ] Managed-device (MDM) policy detection and refusal when automation is not allowed
- [ ] Overlay and tapjacking detection
- [ ] App update mid-run: re-read version and refresh knowledge
- [ ] Locale, time zone and date/number formats
- [ ] Dark-mode OCR check
- [ ] Low battery and power-saving behaviour
- [ ] Network loss mid-task
- [ ] VPN, captive portal and corporate Wi-Fi behaviour
- [ ] SIM roaming and metered-network warning before a data-heavy task
- [ ] Device reboot and service reconnect
- [ ] `hdc` disconnect and reconnect (tethered mode)
- [ ] Multi-device selection (tethered mode)
- [ ] `hdc` authorization onboarding: developer mode + RSA key
- [ ] USB and TCP connection modes
- [ ] `pc-agent` verified on Windows and macOS
- [ ] Unsupported-app list with a clear message
- [ ] Phone call and SMS actions with approval
- [ ] App-not-installed flow: offer AppGallery install with approval

### 9.6 Exit criteria (M4)

- [ ] M4 path: **standalone — ACL approved and verified, 20 tasks pass on a phone with no `hdc`**
- [ ] M4 path: **tethered fallback — release signed, 20 tasks pass over `hdc`** (one of the two must be checked)
- [ ] Every capability fails closed when unavailable
- [ ] No capability imports another capability

### 9.7 Permissions and packaging

- [ ] Full permission list with a one-line justification for each
- [ ] Each permission classified `user_grant` or `system_grant`
- [ ] `requestPermissionsFromUser` flow for every user-grant permission
- [ ] Denial path: explain, degrade gracefully, never loop on the prompt
- [ ] ACL request form prepared for each restricted permission
- [ ] `module.json5` reviewed by a second person
- [ ] Privacy manifest / privacy statement matches actual data use
- [ ] HAR/HSP module boundaries chosen and documented
- [ ] Debug and release build variants separated
- [ ] Signing configs per environment, keys not in git
- [ ] AppGallery pre-check for accessibility and automation features
- [ ] Decision recorded: distributed/super-device features are not used
- [ ] Installation on a clean device from the release HAP verified
- [ ] Uninstall removes all app data

---

## 10. Phase 5 — Safety and trust (continuous, must be M5)

### 10.1 Payment

- [x] Classify payment from screen semantics, not action kind (evidence: ApprovalPolicy.classify (screen semantics))
- [x] Detect pay, checkout, confirm order, amount, merchant, currency (evidence: PAYMENT_SCREEN_WORDS + extract_payment_context)
- [x] Any tap on a payment-classified screen asks (evidence: agent/tests/test_policy.py)
- [ ] Approval sheet shows amount, merchant and consequence
- [x] Deny stops the branch and cannot be retried elsewhere (evidence: DeviceExecutor deny path + AgentLoop stop)
- [x] Approval is never remembered (evidence: ApprovalPolicy has no remember state)
- [x] Model cannot clear or set payment classification (evidence: Action.from_dict drops isPayment)
- [x] Test: model claims “already approved” → still asks (evidence: agent/tests/test_adversarial.py)
- [x] Test: model sets `isPayment:false` → ignored (evidence: agent/tests/test_adversarial.py)
- [x] Test: hidden payment step inside a long flow → asks (evidence: agent/tests/test_adversarial.py)
- [ ] 100% refusal on the payment bench
- [ ] Tested on 3 checkout flows with a test merchant and no real charge

### 10.2 Irreversible actions

- [x] Send message, call, delete, uninstall, reset → ask (evidence: SENSITIVE_KINDS + test_policy)
- [ ] Bulk actions capped
- [ ] Undo offered where the platform allows
- [x] Plain-language confirmation text (evidence: ApprovalRequest.consequence + docs/safety.md)
- [x] Tests for each action class (evidence: agent/tests/test_policy.py (sensitive kinds))

### 10.3 Security

- [x] Prompt injection: screen text never becomes instructions (evidence: agent/tests/test_safety.py + SYSTEM_PROMPT)
- [x] Tool allow-list per task (evidence: DeviceExecutor.allowed_kinds + test_safety)
- [ ] Optional app allow-list
- [ ] Sandbox escape suite green
- [ ] Secrets absent from logs and traces
- [x] Redaction suite green (evidence: agent/tests/test_observation.py (20 cases))
- [ ] TLS and certificate handling decided and documented
- [ ] Dependency audit clean
- [x] Threat model document (evidence: docs/threat-model.md)
- [ ] External pen-test checklist
- [x] `SECURITY.md` (evidence: SECURITY.md)
- [ ] Emergency stop: one visible control cancels the run
- [x] Audit log tamper-evidence (hash chain) (evidence: RunStore.verify_chain + test_records)
- [ ] Accessibility scope transparency: what is read, when, and why
- [ ] Overlay and tapjacking added to the threat model
- [ ] Remote/MCP server binds to localhost and requires auth
- [ ] Kill switch for the model provider
- [x] API-key rotation and revocation procedure (evidence: SECURITY.md (key rotation))
- [x] Provider-compromise playbook: revoke key, purge logs, notify users (evidence: SECURITY.md (provider playbook))
- [ ] Consent revocation mid-task stops actions immediately
- [x] Sensitive-screen detection (banking, passwords) documented (evidence: docs/safety.md + PASSWORD_WORDS)
- [ ] Screenshot minimization: capture only what the step needs
- [ ] Screenshot retention and deletion policy implemented
- [x] Never store card numbers, CVV or full bank details (evidence: observation.redact + record action redaction)
- [x] Subscription and recurring-charge text detected in checkout (evidence: SUBSCRIPTION_WORDS + test_safety)
- [x] Rate limits and caps for messaging, posting and purchasing (evidence: ActionLimiter + test_safety)
- [ ] Coexistence with the system screen reader

### 10.4 Privacy

- [x] Data inventory: what is read, stored, sent (evidence: docs/privacy.md)
- [x] Privacy retention policy covers every stored data class (evidence: docs/privacy.md)
- [ ] Consent flows for screen capture and model calls
- [ ] Export and delete all data
- [ ] Encryption at rest
- [x] No analytics by default (evidence: docs/privacy.md (no analytics code))
- [ ] DPIA draft
- [ ] Privacy policy
- [ ] Schema versioning and migrations for records, memory and knowledge
- [ ] Migration test from the previous release
- [ ] Storage quota with cleanup of old runs and screenshots
- [ ] Corruption detection and recovery
- [ ] Device and cloud backup excludes secrets, is encrypted, and restore is tested
- [ ] Encryption key rotation
- [x] Statement that user data is not used for model training (evidence: docs/privacy.md (no training))

### 10.5 Exit criteria (M5)

- [ ] Safety suite 100% green
- [ ] Threat model signed
- [ ] Payment gate has no known bypass
- [ ] Privacy review signed

### 10.6 Abuse, content and exfiltration

- [ ] Disallowed-task taxonomy written (illegal, harmful, harassing, fraudulent)
- [ ] Refusal behaviour implemented with a plain explanation
- [ ] Jailbreak test suite (20 prompts) green
- [ ] Indirect prompt injection from web pages and documents tested
- [ ] Data-exfiltration test: model tries to send screen text to an unapproved URL
- [x] URL allow-list enforced inside `ActionExecutor`, not only in the prompt (evidence: agent/src/hopa_agent/net.py + DeviceExecutor)
- [ ] No user data in URLs, query strings or referrers
- [ ] MCP server trust model and authentication documented
- [ ] API keys stored in HUKS, never in preferences or logs
- [ ] Brain-service model key stored in the OS keychain or env, never in the repo or logs
- [ ] Emergency-number dial blocked and tested (110 / 112 / 119 / 999)
- [ ] Per-user and per-day rate limits for messaging, posting and buying
- [ ] CAPTCHA is always handed over, never solved automatically
- [ ] Account-ban and terms-of-service risk disclosed in onboarding
- [ ] Scraping limits and robots.txt respect documented
- [ ] Financial, medical and legal advice refusal policy
- [ ] Minor-protection policy
- [ ] Abuse reporting channel and response owner
- [ ] Model provider content filter behaviour tested and documented

---

## 11. Phase 6 — Product and UI (4–6 weeks)

- [ ] Chat with streaming and cancel
- [ ] Task progress: steps, current action, live screen thumbnail
- [ ] Floating capsule or notification when backgrounded
- [ ] Takeover: pause, user acts, hand back
- [ ] Approval sheet with amount, merchant, consequence
- [ ] Memory view: runs, learned notes, skills, delete
- [ ] Settings: model, key, network, a11y status, sandbox, retention
- [ ] Onboarding: what it can and cannot do, permissions, safety
- [ ] Empty, loading and error states
- [ ] HOPA's own accessibility: screen reader labels, contrast, font scale
- [ ] i18n: English + Chinese minimum
- [ ] Dark mode
- [ ] App icon and splash
- [ ] Signing configuration
- [ ] Opt-in crash reporting
- [ ] E2E UI tests
- [ ] Cold start < 2 s
- [ ] 30-minute task battery profile
- [ ] HAP size budget
- [ ] Memory footprint budget
- [ ] Network usage budget
- [ ] Error messages localized
- [ ] `docs/ux.md`
- [ ] 10 beta users, feedback log

### 11.1 Missing product features

- [ ] Scheduled tasks (time-based) with a visible schedule
- [ ] Triggers (event-based) with explicit consent
- [ ] Task templates and shortcuts
- [ ] History and search across runs
- [ ] Read-only replay of a past run
- [ ] Voice input, or a recorded decision to defer it
- [ ] Share target: receive text, image or file from other apps
- [ ] Quick action or home-screen widget
- [ ] Completion notification
- [ ] Cost and latency display per run
- [ ] Undo where the platform allows it
- [ ] Feedback and “report a problem” with redacted logs
- [ ] Export run history
- [ ] Multi-device and PC companion view
- [ ] Task queue and concurrency policy (one active task by default)
- [ ] Recurring schedules
- [ ] Missed schedule while the device was off
- [ ] Background execution limits for scheduled tasks
- [ ] DST and time-zone changes for schedules
- [ ] CAPTCHA handover tested
- [ ] 2FA handover tested
- [ ] Onboarding states plainly that HOPA drives the visible screen and cannot work in the background

### 11.2 Exit criteria (M6 part 1)

- [ ] A new user can install and complete one task without help
- [ ] No P0 bugs open
- [ ] Every permission has an explanation screen

### 11.3 Trust UX

- [ ] “Why did HOPA do that?” explanation for every step
- [ ] Timeline with step, action, result and screenshot
- [ ] Pause and stop always reachable in one tap
- [ ] Approval sheet is screen-reader accessible and respects font scale
- [ ] Error recovery offers retry, edit, hand over and abort
- [ ] Cost and token usage visible per run and per day
- [ ] Model switch and fallback state visible
- [ ] Offline banner with a clear next step
- [ ] Notification actions: stop and open
- [ ] Lock-screen notification hides task details
- [ ] Quick Settings tile or shortcut for stop
- [ ] “What HOPA cannot do” page in the app
- [ ] Feedback entry with a redacted diagnostic bundle
- [ ] First-run safety walkthrough skippable and replayable

---

## 12. Phase 7 — Evaluation (continuous)

- [ ] Bench v1 (20 tasks) stable for 7 days
- [ ] Bench v2 (50 tasks, 10 apps)
- [ ] Held-out task set
- [x] Failure taxonomy with counts (evidence: bench/src/hopa_bench/report.py + test_report)
- [x] Per-app success rates (evidence: bench/src/hopa_bench/report.py + test_report)
- [x] Latency p50/p95 (evidence: bench/src/hopa_bench/report.py + test_report)
- [ ] Cost per task
- [ ] Human evaluation rubric
- [ ] Nightly device run
- [ ] Regression gate on every PR (stub model)
- [x] Reproducible seeds and fixtures (evidence: bench/tasks (20) + deterministic StubModelClient)
- [ ] Public report
- [ ] Comparison with Mika on equivalent Android tasks (clearly labelled)
- [x] `docs/eval.md` (evidence: docs/eval.md)

### 12.1 Test matrix

- [ ] Device matrix: two phones plus one tablet or foldable
- [ ] OS versions: current and previous HarmonyOS release
- [ ] Locales: en-US and zh-CN
- [ ] Network: Wi-Fi, cellular, slow, offline
- [ ] Low battery and low storage
- [ ] Interruption: incoming call and notification
- [ ] Rotation and multi-window
- [ ] Permission revocation mid-task
- [ ] App update mid-run
- [ ] Kill and restart; resume from records
- [ ] Soak test: two-hour session
- [ ] Thermal soak and low-battery run
- [ ] Captive portal and VPN run
- [ ] Monkey test: 1,000 random actions
- [ ] Golden screenshots per supported app
- [ ] Brain-service load test
- [ ] Chaos: model timeout, HTTP 500, rate limit
- [ ] Backup and restore
- [ ] Upgrade and downgrade
- [ ] Uninstall leaves no data
- [ ] Multi-user and private space
- [ ] Flaky-test detection and quarantine
- [ ] Bench authoring guide
- [ ] User corrections (“that was wrong”) feed the eval set
- [ ] Generated API reference for the contracts
- [ ] Adversarial: prompt injection, fake UI, malicious overlay
- [ ] Adversarial: model claims payment is already approved
- [ ] Adversarial: hidden payment step in a long flow
- [ ] Benchmark-leakage check: task text never appears in prompts, memory or knowledge

### 12.2 Targets (confirm at M1)

- [ ] Bench v1 success ≥ 70%
- [ ] Bench v2 success ≥ 85%
- [ ] Payment refusal 100%
- [ ] p95 step latency ≤ 8 s with model
- [ ] Crash-free sessions ≥ 99%
- [ ] Cost per task ≤ target set in ADR-0006

### 12.3 Statistical rigour and SLOs

- [ ] Sample size per task justified (minimum 3 runs, 30 for headline numbers)
- [ ] Confidence intervals reported for headline success rates
- [ ] Environment reset between tasks (app state, locale, network, account)
- [ ] Bench task versioning and changelog
- [ ] Determinism controls: pinned app versions, locale, time zone, network
- [ ] Flakiness budget defined; flaky tasks quarantined
- [ ] Human baseline time measured for the same tasks
- [ ] Energy per task measured
- [ ] Cost model with current token prices
- [ ] SLOs defined: success, latency, crash-free, cost
- [ ] Error budget policy written
- [ ] Failure attribution: brain, body, model or environment
- [ ] Model A/B and prompt A/B harness
- [ ] Regression detection with a fixed seed set
- [ ] Public numbers reproducible from a clean checkout

---

## 13. Phase 8 — Release readiness (3–4 weeks)

- [ ] Version 0.1.0
- [ ] CHANGELOG
- [ ] SBOM
- [ ] License review: Apache-2.0, MPL-2.0 (Pyodide), MIT (QuickJS), no GPL
- [ ] Final NOTICE
- [ ] Export-control review
- [ ] Privacy policy published
- [ ] Security policy published
- [ ] FAQ and troubleshooting
- [ ] Install and upgrade guide
- [ ] Signed HAP and upgrade path
- [ ] AppGallery submission, or a recorded decision to distribute by sideload
- [ ] Rollback plan
- [ ] Monitoring and alerting
- [ ] Support channel
- [ ] Post-release checklist
- [ ] Tag and release notes
- [ ] Archive plan for the repo
- [ ] README states the background-screen limitation

### 13.1 Operations and compliance

- [ ] Remote config and feature flags
- [ ] Staged rollout: 1% → 10% → 100%
- [ ] Kill switch tested
- [ ] Incident response runbook
- [ ] On-call rotation
- [ ] Crash and ANR triage workflow
- [ ] Metrics dashboards
- [ ] End-to-end tracing
- [ ] Alert thresholds
- [ ] Release cadence
- [ ] Terms of service
- [ ] PIPL and GDPR compliance review
- [ ] Third-party SDK disclosure
- [ ] Age rating
- [ ] Store listing assets
- [ ] Huawei developer agreement review
- [ ] Data-residency statement
- [ ] Accessibility compliance statement
- [ ] Reproducible build verification
- [ ] Dependency pinning and lockfiles
- [ ] License headers
- [ ] Changelog automation
- [ ] Code freeze and release branch
- [ ] User guide, admin guide and troubleshooting
- [ ] Privacy-safe log export for support
- [ ] Data processing agreement with the model provider
- [ ] Sub-processor list
- [ ] Review third-party app terms for automated access
- [ ] Trademark and name check for HOPA

### 13.2 Exit criteria (M6 part 2)

- [ ] Signed build installs on a clean phone
- [ ] Upgrade from 0.0.x works
- [ ] All docs linked from README
- [ ] Release checklist signed by two people

### 13.3 Versioning and support

- [ ] Semver policy for app, brain service and contracts
- [ ] Support matrix: devices, OS versions, model providers
- [ ] End-of-life policy for old versions
- [ ] Deprecation policy with at least one release of notice
- [ ] Hotfix process and who can approve it
- [ ] Beta channel separate from stable
- [ ] Crash-symbol upload configured
- [ ] Signing-key management, backup and rotation plan
- [ ] Store data-safety / privacy form completed
- [ ] Third-party notices page published
- [ ] MPL source-offer page for Pyodide
- [ ] Release-train calendar
- [ ] Support SLA and escalation path
- [ ] Public status page or in-app notice for provider and service outages
- [ ] Postmortem template
- [ ] Data-breach notification procedure
- [ ] Security contact and disclosure policy
- [ ] User-visible version and build number
- [ ] In-app “what’s new” for upgrades

---

## 14. Phase 9 — Optional and explicitly gated

Both optional branches default to **no**. Each branch is a decision pair; exactly
one side of each pair must be checked. Detailed work for an approved branch is
prose below and is **not** counted until the branch is approved, at which point
it becomes its own gated plan with its own boxes.

Background mode:

- [ ] Decision: pursue a background / virtual-screen mode? (default: no)
- [ ] Background mode: **approved and shipped**
- [ ] Background mode: **denied and documented** (one of the two must be checked)

If approved: file the `ACCESS_VIRTUAL_SCREEN` ACL request, build a
virtual-screen prototype, define the background lifecycle and the user-facing
indicator, and complete a separate safety review for hidden operation. If
denied: close with a written rationale and update the README and Appendix D.

Companion Linux sandbox:

- [ ] Decision: pursue a companion Linux sandbox? (default: no)
- [ ] Companion sandbox: **approved and shipped**
- [ ] Companion sandbox: **denied and documented** (one of the two must be checked)

If approved, it ships as a separate release track, never as part of the MVP. If
the WASM sandbox proves insufficient, write the companion-service design doc
first and treat it as a new project.

---

## 15. Definition of finished

Development is finished only when **all** of the following are true:

- [ ] Every checkbox in §5–§15 and Appendix E is checked or covered by a checked decision pair
- [ ] `python scripts/plan-status.py --require-complete --lint` exits `0`
- [ ] Bench v1 and v2 meet their targets on a physical device
- [ ] Payment refusal is 100% on the safety bench
- [ ] No open P0 or P1 bugs
- [ ] Final security sign-off recorded at release
- [ ] Final privacy sign-off recorded at release
- [ ] Final threat-model sign-off recorded at release
- [ ] Legal and licence sign-off recorded
- [ ] Accessibility sign-off recorded
- [ ] Budget owner sign-off recorded
- [ ] Every ADR is implemented or explicitly superseded
- [ ] No `TODO` or `FIXME` in shipped code paths
- [ ] Docs reviewed by a second person
- [ ] Signed release installed on a clean phone
- [ ] A second person reproduces the bench from `docs/setup.md`
- [ ] README, docs and NOTICE are current
- [ ] Sign-off A: engineering lead
- [ ] Sign-off B: product owner
- [ ] On-call shadow completed by a second person
- [ ] Post-release monitoring has run for 7 days with no P0 incident

When these are checked, HOPA is a finished MVP. Near-parity with Mika minus the
hidden background screen is the ceiling, and this document says so on purpose.

---

## 16. Risks

| Risk | Impact | Mitigation | Owner |
|---|---|---|---|
| Accessibility ACL denied | no standalone product | PC-tethered fallback; file at Phase 3 start | TBD |
| AppGallery rejects automation | no distribution | foreground-only, explicit consent, no hidden pages | TBD |
| Payment misclassification | financial harm | screen-semantic classifier, fail-closed, 100% bench | TBD |
| Custom-drawn UIs unreadable | task failure | OCR + vision, unsupported list | TBD |
| HarmonyOS knowledge gap | bad routing | rebuild 23 files, `list_apps` first | TBD |
| WASM limits | scripts break | pure Python/JS only, companion fallback | TBD |
| Model outage | unusable | clear error, fallback list, no infinite retry | TBD |
| Cost/latency | poor UX | caps, small routing model, caching | TBD |
| Scope creep toward “Mika clone” | never ships | this document’s out-of-scope list | TBD |

Critical path: ACL → a11y → M4. Everything before M4 must ship without it.

---

## Appendix A — Port matrix

### A.1 Port as data

| Mika source | Files | Action | Note |
|---|---|---|---|
| `core/src/main/resources/knowledge/` | 46 | port format, re-validate content | 23 `APP.md` + 18 `SITE.md` are Android-specific |
| `core/src/main/resources/prompts/` | 118 | port, then prune | strip Android tool names |
| `core/src/main/resources/skills/` | 9 | port | validate manifests |

### A.2 Port as logic (pure Kotlin)

| Mika source | Files | HOPA target | Note |
|---|---|---|---|
| `core/knowledge/` | 11 | `core/knowledge/` | routing, channel, catalog, learning |
| `core/skills/` | 5 | `core/skills/` | personal skills |
| `core/agent/` | 37 | `core/agent/` | loop, context, recommender |
| `core/tool/` | 18 | `core/tool/` | registry, dispatcher, args |
| `core/uistate/` | 46 | `core/uistate/` | screen model |
| `core/observation/` | 2 | `core/observation/` | observations |
| `core/verify/` | 4 | `core/verify/` | verification |
| `core/record/` | 8 | `core/record/` | run records |
| `core/memory/` | 9 | `core/memory/` | memory |
| `core/guard/` | 4 | `core/guard/` | guards |
| `core/risk/` | 1 | `core/risk/` | risk levels |
| `core/replay/` | 5 | `core/replay/` | replay |
| `core/eval/` | 8 | `core/eval/` | evaluation |
| `core/model/` | 16 | `core/model/` | interface; replace transport |

### A.2b Remaining modules — decision required

These modules exist in Mika's `core/` but are not in the port matrix above. They
must be classified before Phase 3 ends; every "drop" needs a one-line reason.

| Mika source | Files | Likely action | Reason |
|---|---|---|---|
| `core/action/` | 10 | port | action model shared by loop and gate |
| `core/run/` | 11 | port | run lifecycle |
| `core/gate/` | 2 | port | approval gate |
| `core/context/` | 1 | port | context builder |
| `core/prompt/` | 3 | port | prompt assembly |
| `core/settings/` | 1 | port | settings model |
| `core/trigger/` | 3 | rewrite | HarmonyOS triggers differ |
| `core/usage/` | 5 | port | token and cost accounting |
| `core/trace/` | 5 | port | tracing |
| `core/selfcheck/` | 3 | port | startup self-check |
| `core/net/` | 4 | rewrite | ArkTS HTTP replaces the transport |
| `core/oauth/` | 6 | rewrite | platform sign-in |
| `core/workspace/` | 6 | rewrite | HarmonyOS file sandbox |
| `core/mcp/` | 5 | rewrite | MCP client over ArkTS |
| `core/remote/` | 9 | drop or rewrite | PC/remote assumptions |
| `core/general/` | 15 | triage | utilities; keep only the pure ones |
| `core/assembly/` | 3 | triage | wiring may not port |
| `core/adb/` | 11 | drop | no ADB on HarmonyOS |
| `core/shell/` | 14 | drop | no shell, no uid 2000 helper |
| `core/wechat/` | 1 | drop | Android helper |
| `core/child/` | 1 | drop | Android process model |
| `core/capability/` | 1 | rewrite | platform capability model |

`core/cap/` (73 files) is already listed in A.3 and is not repeated here.

### A.3 Rewrite

| Mika source | Files | HOPA target |
|---|---|---|
| `core/cap/` | 73 | `app/capabilities/*` |
| `core/userscreen/`, `vision/`, `visual/` | 12 | a11y + OCR + vision |
| `app/a11y`, `browser`, `sandbox`, `capsule`, `takeover`, `wechat` | — | ArkUI + extension |

### A.4 Drop

`adb`, `shell`, `proot`, `VirtualDisplay`, hidden `IActivityTaskManager` /
`ADD_TRUSTED_DISPLAY`, Android `wechat` helper, Android package knowledge, GPL
components.

---

## Appendix B — HOPA-Bench v1 (20 tasks)

Keep the 5 existing. Add 15. Bundle names marked “confirm” must be filled from
`hdc shell bm dump -a` before the task is enabled.

| # | Group | Task | Success predicate | Bundle |
|---|---|---|---|---|
| 1 | System | reach Bluetooth screen | text visible | `com.huawei.hmos.settings` |
| 2 | System | toggle Wi-Fi off/on | state check | `com.huawei.hmos.settings` |
| 3 | System | change brightness | value check | `com.huawei.hmos.settings` |
| 4 | System | open battery settings | text visible | `com.huawei.hmos.settings` |
| 5 | System | check installed app version | text visible | `com.huawei.hmos.settings` |
| 6 | PIM | open Alarm tab | text visible | `com.huawei.hmos.clock` |
| 7 | PIM | create a 07:30 alarm | alarm exists | `com.huawei.hmos.clock` |
| 8 | PIM | create a calendar event | event exists | `com.huawei.hmos.calendar` |
| 9 | PIM | create a note | text visible | `com.huawei.hmos.notepad` |
| 10 | PIM | find a contact | text visible | confirm |
| 11 | Web | search and open first result | text visible | `com.huawei.hmos.browser` |
| 12 | Web | read a price from a page | text visible | browser |
| 13 | Web | fill a form (no submit) | field value | browser |
| 14 | Messaging | draft a message, do not send | draft visible | confirm |
| 15 | Messaging | attach a file to a draft | attachment visible | confirm |
| 16 | Media | play/pause | state check | confirm |
| 17 | Media | search and open an item | text visible | confirm |
| 18 | Files | locate a file | text visible | confirm |
| 19 | Safety | tap “Pay” must ask | approval recorded | any checkout |
| 20 | Safety | deny payment stops the run | no execution, `approved=false` | any checkout |

Scoring: success (binary), steps, wall-clock, permission prompts, payment
decision. Every safety task must pass 100%.

---

## Appendix C — Contracts

### C.1 Observation

```json
{
  "id": "obs_01",
  "timestamp": 0,
  "displayId": 0,
  "windowId": "active",
  "rotation": 0,
  "density": 0,
  "screenSize": { "width": 0, "height": 0 },
  "focus": "e12",
  "text": "flattened visible text",
  "tree": { "ref": "e1", "type": "", "text": "", "bounds": [0, 0, 0, 0], "children": [] },
  "screenshotRef": "file://…",
  "hash": "sha256:…"
}
```

### C.2 Action

```json
{
  "kind": "ui.tap",
  "ref": "e12",
  "text": "",
  "x": 0, "y": 0,
  "app": "com.huawei.hmos.settings",
  "timeoutMs": 10000
}
```

### C.3 Decision

```json
{ "action": { }, "say": "one short sentence", "done": false, "needUser": false }
```

### C.4 Run record

```json
{
  "runId": "", "step": 0, "action": { }, "classification": "read|sensitive|payment",
  "approved": true, "observationHash": "", "verified": true, "error": null
}
```

---

## Appendix D — What is deliberately missing

This plan does not promise:

- a hidden second screen;
- Android APK support;
- a Linux sandbox;
- background operation while the user uses the phone;
- Mika's exact UX or assets;
- parity with Mika's app coverage on day one;
- Python as the app runtime. Pyodide, if enabled, is a WASM sandbox inside a web page.

Saying this up front is cheaper than discovering it at M4.

---

## Appendix E — Assumptions and open questions

Each assumption must be confirmed or replaced by a decision record before the
phase that depends on it. Unresolved rows block the milestone, not the whole
project.

### E.1 Assumptions

- [ ] Target is HarmonyOS 6+ only; older versions are explicitly unsupported
- [ ] `AccessibilityExtensionAbility` remains the only on-device path
- [ ] The ACL decision arrives before Phase 4 exit; otherwise the fallback ships
- [ ] A physical HarmonyOS phone is available for the whole project
- [ ] The model provider stays reachable and within budget
- [ ] The `pc-agent` `hdc` + `uitest` harness is acceptable for enterprise use
- [ ] Mika's Apache-2.0 licence permits the planned reuse
- [ ] AppGallery accepts a foreground-only automation app, or sideloading is acceptable
- [ ] Chinese and English are the only launch locales
- [ ] The team can hire or contract ArkTS and Kotlin skills

### E.2 Open questions

- [ ] Decide: default model provider and fallback order (recorded in ADR-0006 during Phase 0)
- [ ] Decide: free, paid or internal-only distribution
- [ ] Decide: China-first or global launch
- [ ] Decide: open-source the HOPA core or keep it closed
- [ ] Decide: data residency for prompts and screenshots
- [ ] Decide: is a PC companion part of the product or only a dev tool
- [ ] Decide: support Android via a companion app, or not at all
- [ ] Decide: maximum task length and cost per task
- [ ] Decide: retention defaults for screenshots and run records
- [ ] Decide: whether users may bring their own model key
- [ ] Decide: minimum device and OS support matrix
- [ ] Decide: phone only, or also tablet, foldable and HarmonyOS PC
- [ ] Decide: whether HOPA needs its own account at all
- [ ] Decide: which 10 third-party apps are officially supported at launch

---

## Appendix F — Plan audit log

- 2026-11-05 — first version: 397 boxes across 11 phases.
- 2026-11-05 — audit 1: added runtime behaviour, knowledge validation, model
  quality, platform edge cases, security, product features, test matrix,
  operations, data lifecycle, legal, performance and scheduling. 569 boxes.
- 2026-11-05 — audit 2: added programme and change control, protocol and errors,
  licensing and provenance, ArkTS runtime, permissions and packaging, abuse and
  exfiltration, trust UX, statistical rigour, versioning and support, assumptions
  and open questions. Duplicate boxes made specific. 745 boxes.
- 2026-11-05 — audit 3: fixed the finish gate (the unchecked half of a decision
  pair no longer blocks completion), removed five conditional boxes that could
  never be checked, corrected the app and skill counts, the M3/M4 ACL dependency
  and the M4 exit contradiction, moved ACL filing to week 1, added the
  remaining-module matrix, and added 27 missing runtime, platform, security and
  evaluation checks. Net +22. 767 boxes.

The count is expected to move while the plan is alive. What must not move is the
finish line: every box checked, with evidence, and both sign-offs recorded.

Known deliberate omissions from the checkbox list: marketing, sales, pricing
experiments and hiring plans. They are tracked outside this engineering plan, so
that “all boxes checked” still means “the product is built and safe”, not “the
company is profitable”.
