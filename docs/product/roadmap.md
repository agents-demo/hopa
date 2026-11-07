# HOPA roadmap (G1–G4)

> **Superseded for delivery tracking.**
> [docs/plan/README.md](../plan/README.md) is the working plan with checkboxes and
> the definition of finished. This page keeps the original public G1–G4 scope.

HOPA is delivered in four milestones. The committed schedule and numeric targets
live in the private project plan; this document describes the public scope.

## G1 — PC-driven proof of concept & HOPA-Bench v0

**Deliverable:** a PC agent controls a HarmonyOS device over `hdc` + `uitest`
(layout, tap, type, screenshots) via a CLI and an MCP server; HOPA-Bench provides
a scored task format, a runner, and example tasks.

This repository is the G1 seed:

- ✅ `pc-agent` CLI + MCP server (dump, tap, type, swipe, screenshot, launch).
- ✅ `harness/bench/` task format, runner, stub model, and example tasks.
- ✅ `apps/harmony/` scaffold with `core/` action gate + host unit tests.

Remaining to close G1:

- Grow HOPA-Bench to a scored suite over the target apps, with a scoring protocol
  and a reproducible baseline report.
- Run the suite on a physical HarmonyOS 6+ phone (the emulator is a proxy).
- Wire `pc-agent` MCP into the model-serving infrastructure.
- Record baseline success rate, median step latency, and failure taxonomy.
- Validate the payment-refusal tasks (the gate must block every payment until
  confirmed).

## G2 — ArkTS agent runtime

**Deliverable:** agent loop, gated action executor, multi-provider model client,
memory, scheduled tasks, run records and recovery, payment approval policy.

Work:

- Harden `core/`: planner/verifier prompts, retries, cost/latency caps, recovery.
- Multi-provider model client (OpenAI-compatible first), secure key storage.
- Memory: episodic run records, task history, user preferences, redaction.
- Scheduled tasks and resumable runs; append-only run records with replay.
- Approval UX (payment sheet with amount/merchant/consequence) and an adversarial
  policy test suite.

Exit criteria:

- A scored benchmark with a documented baseline and a **100% payment-gate
  compliance** rate.
- Red-team prompts cannot talk the agent past the gate.
- Memory view shows accurate, redacted history.

## G3 — On-device control: apps, web & sandbox

**Deliverable:** accessibility app control (background screens if the ACL is
granted); ArkWeb browser agent; system intents; human takeover; Wasm sandbox with
an optional cloud fallback.

Work:

- `capabilities/a11y`: full AccessibilityExtensionAbility after the **ACL request
  for accessibility** is approved; foreground-only fallback otherwise.
- Background/virtual-screen control behind `ACCESS_VIRTUAL_SCREEN` (restricted /
  ACL); never assume it is granted.
- `capabilities/web`: navigate/read/click/type with per-task network gating.
- `capabilities/system`: alarm, calendar, deep links (https allow-list).
- Human takeover for login and payment (pause, hand control to the user, resume).
- `capabilities/sandbox`: Pyodide + QuickJS from bundled assets, offline by
  default, with an explicit cloud fallback.

Exit criteria:

- On a physical HarmonyOS 6+ phone, a multi-app task runs end-to-end without
  `hdc`.
- Sandbox runs Python and JS offline and is verified to have no network/file
  access.
- Accessibility/virtual-screen capabilities are either approved and verified or
  surfaced as unavailable with ACL status documented.

## G4 — HOPA MVP app & evaluation

**Deliverable:** ArkUI app (chat, progress, floating capsule, memory), with
performance, privacy, security, and evaluation work.

Work:

- Floating capsule + task progress + memory UI polish.
- Performance: startup, action latency, battery; emulator + device profiles.
- Security/privacy: sandbox escape tests, permission minimization, encrypted
  on-device memory, DI + DPIA evidence.
- SBOM + license review (Mika Apache-2.0 reference; Pyodide MPL-2.0; QuickJS MIT;
  **no GPL sandbox code**), export-control review before external transfer.
- Evaluation report, patents, and a reproducible release pipeline.

Exit criteria:

- Release candidate passes the full benchmark and the security checklist.
- All restricted permissions have approved ACLs, or the features are disabled.
- A new teammate can build, test, and run the benchmark from `docs/guides/setup.md`.

## Dependencies and risks

- **ACL / review** for accessibility and `ACCESS_VIRTUAL_SCREEN` — the critical
  path for background control; foreground-only fallback is required.
- No ADB self-connection or JVM on-device; no Linux sandbox.
- Custom-drawn UIs break pure accessibility-tree automation → OCR + vision
  fallback.
- Irreversible actions (payment, send, delete) must be safe by construction.
- Privacy: reads screen content (messages, contacts, orders) and stores user
  memory → encrypted on-device storage, minimization, consent, DI + DPIA.
