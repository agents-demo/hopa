# HOPA rebuild plan and roadmap

**This document is the contract.** Development is finished when every checkbox in
Â§5â€“Â§15 is checked, `python tools/scripts/plan-status.py --require-complete` exits `0`,
and the two sign-offs in Â§15 are recorded.

HOPA keeps its own name, UI and NOTICE.

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
- Conditional work ("if approvedâ€¦", "if neededâ€¦") is prose, not a checkbox.
  Once a branch is approved it becomes its own gated plan with its own boxes.
- Do not add checkboxes casually. Every box must be verifiable by a third party.
- Box size is not uniform: one box may be an hour or a two-week epic. The
  percentage is a count, not a schedule. Exit criteria, not the count, decide a
  milestone.
- `python tools/scripts/plan-status.py --lint` must pass: no duplicate boxes, every
  `[x]` carries `(evidence: â€¦)`, and no decision pair is double-checked.

### 1.2 Progress

```bash
python tools/scripts/plan-status.py                 # per-phase table
python tools/scripts/plan-status.py --lint          # check evidence, duplicates, decision pairs
python tools/scripts/plan-status.py --require-complete   # exit 1 until finished
```

### 1.3 Milestones

| Milestone | Phases | Meaning |
|---|---|---|
| M0 | 0 | Foundations: CI green, decisions recorded, baseline measured |
| M1 | 1 | PC harness closes the observeâ†’actâ†’verify loop on 5 tasks |
| M2 | 2 | The reference brain runs HOPA's body; 20-task bench published |
| M3 | 3 | ArkTS core reaches parity with the JVM brain |
| M4 | 4 | On-device control works without a PC (or fallback signed) |
| M5 | 5 | Safety and privacy suites pass; payment gate is unbypassable |
| M6 | 6â€“8 | Usable app, evaluated, signed, released |

### 1.4 Estimates

4â€“6 people, 4â€“6 months to MVP; 9â€“12 months to near-parity. Phase 4 and Phase 7
run in parallel with Phase 3. The critical path is **ACL approval â†’ on-device
a11y â†’ M4**. Everything before M4 must not depend on the ACL.

M3 proves the on-device loop on **ArkWeb surfaces** (no ACL needed). Driving
other apps on-device still needs the accessibility ACL, so M3 alone does not
satisfy M4. Do not let M3's "runs with no PC" claim hide that dependency.

Cross-cutting work in Â§5.5, Â§6.8, Â§7.9, Â§8.6, Â§9.7, Â§10.6, Â§11.3, Â§12.3 and
Â§13.3 is not a separate phase. It lands inside the phase that owns it and is
counted there. Appendix E must be resolved before the milestone that depends on
it, not at the end.

---

## 2. Scope

### 2.1 In scope

- A GUI agent that operates HarmonyOS apps and websites: read screen, tap, type,
  scroll, navigate, verify.
- App routing: name / alias / domain â†’ app; unknown installed app still operable.
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
- Copying a third-party name, UI assets or GPL components.

### 2.3 Non-negotiables

- One execution path: every action passes `ActionExecutor`.
- Payment is fail-closed and never remembered.
- Append-only run records.
- No secrets in logs or git.
- The README states plainly that there is no background screen.
- No Python runtime in the HAP. Pyodide, if ever enabled, is WASM inside a web page, not the app runtime.

---

## 3. Current state (audited 2026-11-06)

| Area | State | Evidence |
|---|---|---|
| Repo | public, Apache-2.0 | `git log` |
| `apps/harmony/core` | screen-aware gate, observation loop, tool registry, types, model interface; hypium tests pass | `apps/harmony/core/src` |
| `apps/harmony/capabilities` | interfaces + web bridge (ArkWeb), a11y extension declared with the ACL granted on the emulator, sandbox stub, system intents | `module.json5`, `BrowserController.ets` |
| `apps/harmony/phone` | 6-tab ArkUI app (Chat, Web, Apps, Tasks, Settings, Memory) wired to `AgentLoop`; approval sheet; providers; memory; skills; run history | `pages/Index.ets` |
| Agent loop | captures the screen, asks for one action, gates, records | `AgentLoop.ets` |
| `pc-agent` | CLI + MCP implemented: devices, dump, tap, double-tap, long-press, type, swipe, screenshot, launch, stop, key, install, uninstall, apps | `services/pc-agent/src` |
| `bench` | 20 task files; 5/7 tasks pass on the emulator (strict: a failed step cannot pass) | `harness/bench/tasks`, `docs/product/bench-results-v0.md` |
| Brain | Kotlin router + HTTP service + knowledge + prompts + skills + sites (98 assertions + schema contract) | `services/brain/src`, `docs/reference/brain.md` |
| HAP | builds with DevEco 6.1.1 / API 24; signed with the SDK local debug kit; installed with the ACL permission on the Pura 90 emulator | `tools/scripts/sign-app.ps1` |
| Knowledge | 35 apps (12 system + 23 catalogued), 21 sites, 6 skills | `services/brain/knowledge`, `docs/history/knowledge-triage.md` |
| CI | Python tests + ruff; HAP build and core Local Tests skip with a warning when the mirrored toolchain secret is absent | `.github/workflows/ci.yml` |
| Tests baseline | 277 Python tests, 98 Kotlin assertions, ArkTS Local Tests pass; 20 bench tasks validate; device bench 5/7 | local run 2026-11-06 |

Known gaps to close first:

- The accessibility extension is declared and the ACL is granted on the emulator, but this image has no Settings page to enable a third-party service, so the loop cannot read or act on other apps yet.
- No app routing, no knowledge, no skills, no memory.

---

## 4. Target architecture

```
ArkUI entry (chat / tasks / settings / memory / takeover / approval)
        â”‚
core/  AgentLoop â”€â”€ ModelClient (OpenAI-compatible)
        â”‚
        â””â”€â”€ ActionExecutor        â† the only execution path
              guards â†’ approval â†’ execute â†’ verify â†’ record
                       â”‚
        capabilities/  a11y | web | sandbox | system
                       â”‚
              HarmonyOS device

Brain host:
  M1â€“M2: local JVM service, HTTP / MCP
  M3+:   ArkTS core on device, same contract, golden-file parity

Harness: pc-agent (hdc + uitest) + HOPA-Bench
```

Module responsibilities:

| Module | Owns | Must not |
|---|---|---|
| `core/` | loop, gate, routing, memory, records | import UI or platform APIs |
| `capabilities/*` | one platform surface each | import each other |
| `entry/` | UI, permissions, wiring | contain agent logic |
| `services/pc-agent/` | device I/O for development | be required at runtime |
| `harness/bench/` | tasks, runner, scoring | be imported by the app |

---


## Contents

1. [Phase 0: foundations](phase-0-foundations.md)
2. [Phase 1: harness](phase-1-harness.md)
3. [Phase 2: brain](phase-2-brain.md)
4. [Phase 3: ArkTS core](phase-3-arkts-core.md)
5. [Phase 4: capabilities](phase-4-capabilities.md)
6. [Phase 5: safety](phase-5-safety.md)
7. [Phase 6: product and UI](phase-6-product-ui.md)
8. [Phase 7: evaluation](phase-7-evaluation.md)
9. [Phase 8: release](phase-8-release.md)
10. [Phase 9: optional](phase-9-optional.md)
11. [Definition of finished](definition-of-finished.md)
12. [Risks](risks.md)
13. [Appendix A: port matrix](appendix-a-port-matrix.md)
14. [Appendix B: bench](appendix-b-bench.md)
15. [Appendix C: contracts](appendix-c-contracts.md)
16. [Appendix D: missing](appendix-d-missing.md)
17. [Appendix E: open questions](appendix-e-open-questions.md)
18. [Appendix F: audit log](appendix-f-audit-log.md)
