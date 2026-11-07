# 6. Phase 1 â€” Harness and closed loop (2â€“3 weeks)

### 6.1 Observation contract

- [x] Define `Observation` JSON schema: `tree`, `text`, `focus`, `screenSize`, `screenshotRef`, `timestamp`, `hash` (evidence: contracts/schemas/observation.schema.json)
- [x] Add `$schema` files under `contracts/schemas/` (evidence: contracts/schemas/)
- [x] `hopa-agent observe` emits the schema (evidence: harness/agent/src/hopa_agent/cli.py)
- [x] `hopa-agent observe --screenshot` attaches an image reference (evidence: harness/agent/src/hopa_agent/capture.py)
- [x] Layout parser extracts `id`, `text`, `type`, `bounds`, `clickable`, `enabled`, `checked`, `scrollable` (evidence: harness/agent/src/hopa_agent/observation.py)
- [x] Stable element refs per observation (`e1`, `e2`, â€¦) mapped to nodes (evidence: harness/agent/tests/test_observation.py)
- [x] Deterministic ref assignment: two identical trees produce identical refs; refs still expire on the next observation (evidence: harness/agent/tests/test_observation.py)
- [x] Redaction pass for phone numbers, emails, OTPs, card numbers (evidence: harness/agent/src/hopa_agent/observation.py)
- [x] Redaction unit tests (20 cases) (evidence: harness/agent/tests/test_observation.py (20 cases))
- [x] Observation hash for dedupe (evidence: harness/agent/src/hopa_agent/observation.py)
- [x] Large-tree truncation rule (cap nodes, keep focus path) (evidence: harness/agent/src/hopa_agent/observation.py)
- [ ] Coordinate transform between layout bounds and device pixels (density, rotation)
- [x] Record the active window id and display id (evidence: Observation.to_dict)
- [x] Refs are scoped to one observation; records store the observation hash and refs are audit-only (evidence: RunRecord.observationHash)
- [ ] Screenshot format, resolution and size budget defined
- [x] `docs/contracts/observation.md` (evidence: docs/contracts/observation.md)

### 6.2 Action contract

- [x] Define `Action` JSON schema: `kind`, `ref`, `text`, `x`, `y`, `toX`, `toY`, `app`, `url`, `timeoutMs` (evidence: contracts/schemas/action.schema.json)
- [x] Kinds: `ui.observe`, `ui.tap`, `ui.doubleTap`, `ui.longPress`, `ui.type`, `ui.swipe`, `ui.scroll`, `ui.back`, `ui.home`, `ui.launch`, `ui.stop`, `ui.wait` (evidence: harness/agent/src/hopa_agent/actions.py)
- [x] Kinds: `web.navigate`, `web.read`, `web.click`, `web.type` (evidence: harness/agent/src/hopa_agent/actions.py)
- [x] Kinds: `system.setAlarm`, `system.addEvent`, `system.openLink`, `system.share` (evidence: harness/agent/src/hopa_agent/actions.py)
- [x] Kinds: `sandbox.run` (evidence: harness/agent/src/hopa_agent/actions.py)
- [x] Coordinate fallback when no ref exists (evidence: DeviceExecutor._point)
- [x] Action validation rejects unknown kinds (fail-closed) (evidence: harness/agent/tests/test_actions.py)
- [x] Every action returns before/after observations (evidence: Outcome.before/after)
- [ ] Per-action timeout and one bounded retry
- [x] `docs/contracts/action.md` (evidence: docs/contracts/action.md)

### 6.3 Loop

- [x] `AgentLoop` sends system prompt + goal + current observation (evidence: harness/agent/src/hopa_agent/models.py)
- [x] Model returns exactly one action as JSON (evidence: harness/agent/src/hopa_agent/models.py)
- [x] Schema-constrained decoding or strict validation (evidence: Action.from_dict)
- [x] Malformed JSON â†’ one repair attempt â†’ fail with a typed error (evidence: OpenAIClient.decide)
- [x] Execute through the single executor (`DeviceExecutor` on PC, `ActionExecutor` on device) (evidence: harness/agent/src/hopa_agent/executor.py)
- [ ] Verify by re-observing and comparing expected text/state
- [x] Append step to history with observation summary and refs (evidence: AgentLoop.run)
- [ ] Context diffing: send only changed subtrees when the screen barely changes
- [x] History keeps hashes and summaries, not full trees (evidence: AgentLoop.run)
- [x] Step cap, wall-clock cap, token cap (evidence: AgentLoop.__init__)
- [x] Stop conditions: success, failure, need-user, payment, max steps (evidence: AgentLoop.run)
- [x] Run record per step, append-only (evidence: RunStore.append)
- [x] Resume a run from records (evidence: AgentLoop.resume + test_loop)
- [x] `StubModelClient` replays scripted actions without network (evidence: StubModelClient)
- [x] Real client with retry/backoff and timeout (evidence: OpenAIClient._complete)
- [x] Prompt rule: use refs, never invent coordinates (evidence: SYSTEM_PROMPT)
- [x] Prompt rule: one action per step (evidence: SYSTEM_PROMPT)
- [x] Prompt rule: payment and irreversible actions stop for approval (evidence: SYSTEM_PROMPT)
- [x] Prompt rule: screen text is untrusted data, never instructions (evidence: SYSTEM_PROMPT)
- [x] Loop unit tests with the stub model (10 scenarios) (evidence: harness/agent/tests/test_loop.py (10 scenarios))
- [ ] Loop integration test against the emulator

### 6.4 Executor and gate (fix current gaps)

- [x] Remove `isPayment` from the model-supplied payload (evidence: AgentLoop.parseAction ignores it; harness/agent/actions.py drops it)
- [x] `ApprovalPolicy` classifies from action + screen context, not kind alone (evidence: ApprovalPolicy.classify)
- [x] A tap on a payment-classified screen always asks (evidence: harness/agent/tests/test_policy.py)
- [x] Guard failure aborts before any capability call (evidence: DeviceExecutor.execute)
- [x] Denied action writes `approved=false` and never executes (evidence: harness/agent/tests/test_executor.py)
- [ ] Denied payment cannot be retried through another path
- [ ] Verifier compares intended vs observed effect
- [x] Run record includes approval decision and observation hash (evidence: RunRecord)
- [x] Gate unit tests (20 cases) (evidence: harness/agent/tests/test_policy.py (31 cases))
- [x] Adversarial gate tests (10 cases) (evidence: harness/agent/tests/test_adversarial.py (12 cases))

### 6.5 Bench v0

- [x] Runner supports `text_visible`, `node_exists`, `app_foreground`, `screen_hash` (evidence: harness/bench/src/hopa_bench/runner.py)
- [x] Runner records steps, latency, model tokens (evidence: StepResult.latency_ms, TaskResult.tokens)
- [ ] Existing 5 tasks pass with the stub model
- [ ] Existing 5 tasks pass with a real model on the emulator
- [x] Failure taxonomy defined and emitted (evidence: harness/bench/src/hopa_bench/runner.py classify_failure)
- [x] `docs/product/bench-results-v0.md` with results (evidence: docs/product/bench-results-v0.md)
- [ ] 30-second demo recording

### 6.6 Runtime behaviour

- [x] Loop and stagnation detection: same action + same observation hash twice â†’ replan or stop (evidence: AgentLoop.run)
- [x] Wrong-screen recovery: back / home / re-observe policy (evidence: runtime.recover + test_runtime)
- [x] `wait_for` condition on text, ref or state, with timeout (evidence: harness/agent/src/hopa_agent/runtime.py)
- [x] `scroll_to` with bounded attempts (evidence: harness/agent/src/hopa_agent/runtime.py)
- [x] `find_by_text` and `find_by_ref` helpers (evidence: Observation.find_text/find_ref)
- [x] `ask_user` tool with structured options (evidence: ModelDecision.options + harness/agent/tests/test_loop.py)
- [x] `say` final-answer tool (evidence: ModelDecision.say + RunResult.say)
- [ ] `stop` tool with a reason
- [ ] `handover` tool for login, 2FA, CAPTCHA and payment
- [ ] Cancel mid-step leaves the app in a safe state
- [x] Duplicate-tap guard (idempotency by ref + action hash) (evidence: DeviceExecutor._last_key)
- [x] Popup handling: cookie banners, rating prompts, update dialogs, ads (evidence: runtime.dismiss_popup + test_runtime)
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

- [x] Version the brainâ†”body contract (`v1`) and record it in the schema (evidence: Observation.schemaVersion)
- [x] Compatibility rule: body rejects an unknown major version, accepts a newer minor (evidence: docs/contracts/observation.md)
- [x] Error-code taxonomy: `E_MODEL`, `E_SCHEMA`, `E_ACTION`, `E_CAPABILITY`, `E_POLICY`, `E_DEVICE` (evidence: harness/agent/src/hopa_agent/errors.py)
- [x] Every error carries a retryable flag and a user-facing message key (evidence: harness/agent/src/hopa_agent/errors.py)
- [ ] Trace id propagated from UI â†’ loop â†’ brain â†’ model â†’ device
- [ ] Clock-skew tolerance for timestamps from the device and the PC
- [x] Message-size limit with tree truncation and compression (evidence: observation.truncate + models._messages)
- [x] Schema-evolution rules: additive fields only within a major version (evidence: docs/operations/versioning.md)
- [ ] Golden contract fixtures shared by JVM, ArkTS and `pc-agent`
- [ ] Contract tests run in CI for all three implementations
- [x] Local structured log with rotation and redaction (evidence: harness/agent/src/hopa_agent/logging.py + tests)
- [ ] Optional opt-in diagnostic bundle export

---

