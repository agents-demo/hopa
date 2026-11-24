# Windows client plan (P0–P6)

Status: **P0-P4 code complete (P4 hardware gate pending); P5 done; P6 packaging
in progress; W7-W9 done, W10/W11 in progress.** The shared engine runs headless through the real
gate, the PC adapter implements the whole `DevicePort` contract, and settings
launches use a URI before any click. The product goal is now **semantic parity
with Android** ([ADR-0027](../../../design/decisions/0027-windows-semantic-parity.md));
the phase plan is [total-parity.md](total-parity.md). Re-baselined 2026-11-15
against the Android client (ADR-0020); merged onto the Android parity branch
2026-11-16. Counted with:

```bash
python tools/scripts/plan-status.py --plan docs/project/plan/windows
```

A box is ticked only when the behaviour exists **and** an artifact proves it. Every
tick carries `(evidence: ...)`.

## 1. Position

HOPA's reference client is Android. Windows is a **full client with semantic
parity** ([ADR-0027](../../../design/decisions/0027-windows-semantic-parity.md)):
the same jobs and outcomes, in a desktop-native surface. The PC is especially
good at three jobs:

1. driving desktop applications that expose no intent or API, through UI
   Automation;
2. hosting a long form, a document, or a signature that a phone cannot
   comfortably complete;
3. asking the phone for approval when the action runs on the PC.

Everything else that Android has is still in scope; the screen-by-screen matrix
is [parity.md](parity.md) and the phases are [total-parity.md](total-parity.md).
Parity means **semantic**, not a literal phone screen: the notifier becomes a
Windows toast, accessibility becomes UIA readiness, and "Act → My computer"
becomes a phone handoff rather than a screen mirror.

## 2. Goals

1. **The same brain.** The loop, the gate, the contracts and the records come
   from `packages/`; no second implementation (ADR-0016, ADR-0021).
2. **Two targets from one window.** The Android phone through the bridge, and
   the PC itself through UI Automation, chosen per action.
3. **Honest failure.** Locked screen, elevated window, missing UIA tree, stale
   ref and dead bridge each say what happened, distinctly.
4. **The gate is the gate.** The C# host never decides whether an action is
   allowed. Payment always asks, is never remembered, and a deny executes nothing.
5. **Sideload-first.** A signed MSI on a clean Windows VM with a checksum.

## 3. Non-goals

- A .NET port of the loop or a second shared brain.
- A literal screen-for-screen copy of the phone; desktop adaptations are
  first-class, and `adapt` is a parity status.
- Mirroring the phone screen or driving it as a remote display. A desktop task
  handed to the phone is owned by the phone ([ADR-0024](../../../design/decisions/0024-windows-device-identity-and-approval.md)).
- Batch-approved payments. Payment is one action, one question, every time.
- MSIX, the Microsoft Store and auto-update in v0.
- macOS or Linux hosts.
- Screenshots or screen text in logs, ever.

## 4. Decisions

| Decision | Where |
|---|---|
| Android is the reference client; Windows has full semantic parity | ADR-0020, ADR-0027, [total-parity.md](total-parity.md) |
| .NET 8 + WPF shell, Kotlin engine as a sidecar, NDJSON over stdio | ADR-0021 |
| The client engine is the shared `core/` modules | ADR-0007 addendum |
| Clients own the loop; the bridge stays transport | ADR-0016 |
| PC device control is a `DevicePort` adapter (FlaUI/UIA), like Android's accessibility adapter | ADR-0017 pattern |
| IPC v1 is frozen: `step`, `approval.*`, `session`, `task.*` | [protocol.md](protocol.md) |
| The parity reference is the Android app, screen by screen | [parity.md](parity.md) |
| Parity phases and evidence rules | [total-parity.md](total-parity.md) |

### Android distribution (P0 decision)

The Android app ships **sideload or enterprise first**, and automation is
**intent-first**. Google Play restricts `AccessibilityService` use to genuine
accessibility work, so a Play build must keep the accessibility path optional and
degrade to the intent/API tiers; the enterprise build keeps the full path. The
Windows client has no such constraint and ships as a signed MSI.

This is recorded here because it shapes what the PC may assume: the phone may
legitimately lack the accessibility capability, and the PC must still work.

## 5. Shape

```
apps/windows/
  Hopa.Windows/           WPF app (C#): Ui (Shell, Panes, Chat, Dialogs),
                          Integrations (Engine, Gateway, Voice, Device),
                          Host, Storage, Cli, Checks
  sidecar/                Kotlin engine host for packages/ (NDJSON over stdio)
  installer/              WiX MSI

IPC (stdio, NDJSON, v1):
  host -> sidecar   turn.start, turn.cancel, configure, device.result,
                    approval.result, conversations.*, conversation.*,
                    file.*, task.*, shutdown
  sidecar -> host   ready, step, device.request, approval.request, session,
                    turn.end, log

Targets:
  window -> sidecar -> packages/core loop -> DevicePort
                                            ├─ phone (bridge / adb)
                                            └─ PC (UI Automation, via the host)
```

## 6. Phases

### P0. Re-baseline (0.5 week) — done

Point the UI spec at the Android app, not at a retired shell. Delete the
phases that chased that shell's look. Freeze IPC v1. Decide the Android
distribution model.

- [x] The plan is re-baselined against `apps/android`; no frozen-client screen is referenced. (evidence: this file; docs/project/plan/windows/parity.md)
- [x] The parity checklist names Android screens only, with source paths. (evidence: docs/project/plan/windows/parity.md)
- [x] IPC v1 is frozen: `step`, `approval.*`, `session` and `task.*` have documented shapes and rules. (evidence: docs/project/plan/windows/protocol.md)
- [x] The Android distribution model is decided and recorded. (evidence: this file, "Android distribution")
- [x] The frozen-client parity and surface phases are retired from this plan. (evidence: this file, "Phases")

### P1. Engine parity (1 week) — done

Boot the shared `packages/core` loop inside the sidecar. Use a stub model. Add
the conversation store and records. Expose a headless `--turn` mode.

- [x] The sidecar runs the real `AgentLoop` in a headless `--turn` mode. (evidence: docs/project/evidence/P1-engine.md)
- [x] The scripted model is deterministic, offline and only proposes; it cannot approve anything. (evidence: `apps/windows/sidecar/src/main/kotlin/com/hopa/sidecar/turn/ScriptedModel.kt`; `ScriptedModelTest`)
- [x] Headless approvals deny by default, and the gate is the real `ActionExecutor`. (evidence: `DenyAllApproval.kt`; `HeadlessTurnTest`)
- [x] A denied payment leaves `executed=false`, `approved=false`, and never reaches the device. (evidence: `HeadlessTurnTest.payment_is_refused_before_the_device_is_touched`; docs/project/evidence/P1-engine.md)
- [x] Conversations and records survive a reload, and the record chain verifies. (evidence: `HeadlessTurnTest`; docs/project/evidence/P1-engine.md)

Gate: `--turn "say hello"` answers, and `--turn "pay 100"` records a refusal with
no device call.

### P2. PC target (2.5 weeks) — done

Wire `WindowsDevice` behind `DevicePort`. Observe the UIA tree. Act by pattern
first, coordinates second. Type only with a ref. Launch must prove foreground.
Refuse lock screens and elevated windows. The step-by-step run is
[`docs/guides/windows/p2-testing.md`](../../../guides/windows/p2-testing.md).

- [x] `WindowsDevice` implements the full `DevicePort` contract, including `stop`, `screenshot` and `apps`. (evidence: `WindowsDevice.cs`; docs/project/evidence/P2-device.md "apps: 84", "screenshot: 95984 bytes", "stop a missing app: refused")
- [x] Every action tries the UIA pattern before the input stack and reports which one ran in `device.result.text`. (evidence: P2-device.md "calc tap: invoked e5"; `MainWindow.OnDeviceRequested`)
- [x] `type` without a ref is refused; a stale ref is refused with "observe again". (evidence: P2-device.md "type without ref: refused", "stale ref: refused")
- [x] Launch proves the foreground handle within a bounded wait (12 s, one retry for a cold packaged app) or fails with a readable error. (evidence: P2-device.md "launch notepad: launched ... (foreground=notepad)"; W3-device.md "launched notepad (foreground=notepad)")
- [x] Lock screen, elevated window and no-tree app each produce a distinct message. (evidence: `RefuseSecureSurface`, `RefuseElevatedBoundary`, `ObservationRules.IsTreeOnlyRoot`; `ObservationRulesTests`)
- [x] Evidence transcript with one benign action and three refusals. (evidence: P2-device.md: Notepad tap/type/read-back, plus blind-type, stale-ref and missing-app refusals)
- [x] Lock-screen and elevated-window refusals captured on a desktop session. (evidence: docs/project/evidence/P2-device.md "Lock-screen and elevated-window refusals"; transcripts `%TEMP%\hopa-p2\lock.txt`, `%TEMP%\hopa-p2\uac.txt`)

Gate: Notepad reads back typed text; a locked screen refuses; a UAC window
refuses with a different sentence.

### P3. Path selector (1.5 weeks) — done

Add four tiers per action: API, intent, UIA, input. Pick the cheapest tier that
works and log which tier fired.

- [x] A tier table maps action kinds to API / intent / UIA / input. (evidence: `WindowsPathSelector`; `WindowsSelectorTest` 7 tests)
- [x] `system.openLink` and app URI activation run before any click. (evidence: docs/project/evidence/P3-intents.md: `step 0: system.openLink tier=intent` for "open wifi settings")
- [x] Each step records the tier it used. (evidence: `RunRecord.tier`, `contracts/schemas/run-record.schema.json`, `Protocol.step`; P3-intents.md)
- [x] A tier that is unavailable falls through to the next one, visibly. The first unavailable tier is refused with `E_UNSUPPORTED`, the tier that ran is recorded, and automatic fallback is implemented; the fall-through is a log line, never silent. (evidence: docs/project/evidence/P3-intents.md "Automatic fallback"; `PathSelectorTest` 6 tests; `WindowsSelectorTest` 10 tests; `HeadlessTurnTest` 8 tests)

Gate: "open Settings → Wi-Fi" uses an intent, not a sequence of clicks.

### P4. Phone link (2 weeks) — code complete

Make the Android app a peer: pair, hand off a task, push approval to the phone,
return the verified result. The transport is the **backend gateway** built by
upstream (ADR-0022), not the legacy relay; device identity and task state come
from the gateway contract (ADR-0024). Do not invent a second transport or a
second task state machine.

- [x] `task.start`, `task.get` and `task.handoff` are implemented against the documented shapes. (evidence: docs/project/evidence/P4-phonelink.md "Task messages"; `TaskStore` 11 tests; real NDJSON transcript)
- [x] A PC action can request approval on the phone and receive allow or deny. (evidence: `GatewayClient.cs`; `RemoteApprovalRunner.kt`; `TaskRoutingTest`; `RemoteApprovalRunnerTest`; docs/project/evidence/P4-phonelink.md)
- [x] The record says who approved and on which device. (evidence: `Approver.kt`, `RunRecord.approver`, `Protocol.step`, `ApprovalProvenanceTest`, P4-phonelink.md)
- [x] A dropped link fails the task with a readable error; the conversation survives. (evidence: `TaskStore.failLink`, `HostApproval` timeout, `RemoteApprovalRunner` deny-on-timeout; P4-phonelink.md "Limits")

Gate: a PC action is approved on the phone and the run record names the phone.

### P5. Signature and HITL (1 week) - done

Add a takeover surface: pause, hand the form to the user, resume. Capture the
verified postcondition.

- [x] The loop can pause before a step and hand the foreground to the user.
  (evidence: `turn.pause`/`turn.resume`; `TakeoverWindow`)
- [x] Resuming re-observes and verifies the postcondition before continuing.
  (evidence: `StepGate.Refresh`; `checkpoints` in `turn.start`/`turn.end`;
  `GoalVerifier`)
- [x] A cancelled takeover leaves the task failed, not silently done. (evidence:
  `AgentLoopTest.a_cancelled_takeover_stops_instead_of_claiming_success`;
  `turn.cancel` releases the pause)
- [x] Evidence: a form pre-filled, signed, submitted and confirmed by a human.
  (evidence: [P5-takeover.md](../../evidence/P5-takeover.md);
  `operator: human`, `checkpoint complete: True`)

Gate: a signed form produces a verified postcondition and a record.

### P6. Package (1.5 weeks)

Ship a jlink runtime plus the sidecar inside a WiX MSI. Add a checksum. Add a
Windows CI runner.

- [ ] The MSI installs the sidecar and a private runtime; no machine-wide Java is required.
  - [x] `windows-package.ps1` builds a WiX MSI from the staged client, sidecar
    jars and jlink runtime; the local run produced
    `hopa-windows-0.1.0.msi` with a recorded SHA-256.
  - [x] An administrative extract contains `Hopa.Windows.exe`, `sidecar\lib`
    and `runtime\bin\java.exe` with `JAVA_VERSION="21.0.11"`.
    (evidence: [P6-package.md](../../evidence/P6-package.md))
  - [ ] Install it on a clean VM and confirm it uses `runtime\bin\java.exe`.
- [ ] A clean VM runs one PC turn and one phone-approved turn.
- [ ] The installer is signed and its hash is recorded.
  - [x] The package script writes `hopa-windows-0.1.0.msi.sha256` and
    `hopa-windows-0.1.0.zip.sha256`.
  - [ ] Sign the MSI with the release certificate and verify it with
    `signtool verify /pa`.
- [x] Windows CI builds, tests and packages on every pull request.
  - [x] CI installs WiX 5, builds the MSI, records both hashes and uploads the
    zip, MSI and hash files.

Gate: a signed MSI on a clean VM, with both targets working.

### Parity phases (W7–W11)

The 2026 engineering modernization proposal is
[windows-2026.md](../modernization/windows-2026.md); it changes foundations, not
product behaviour.

The total-parity work is a separate phase set after P0-P6. W7 makes the contract
reviewable; W8 builds the shared data and protocol path; W9–W10 add the
information and action surfaces; W11 proves the matrix. Details, checkboxes and
evidence rules are in [total-parity.md](total-parity.md).

Gate: every row in [parity.md](parity.md) is `have`, `adapt` or `new` with an
artifact, or `not-applicable` with a written platform reason.

## 7. Acceptance: assertions, not "opens"

| Area | Assertion | Artifact |
|---|---|---|
| Startup | the window opens and the sidecar is ready within 10 s | log + screenshot |
| Chat | a message produces an answer; restart keeps it | screenshot + store dump |
| Phone target | `ui.launch` on the phone changes the foreground app | before/after observation |
| PC target | a click in Notepad changes the document text | before/after tree + screenshot |
| Gate | a payment waits for approval; deny leaves `executed: false` | record dump |
| Honest failure | lock, elevation and no-tree each give a different message | transcripts |
| Records | tampering a field makes `verifyChain` fail | test log |
| Installer | signed MSI installs on a clean VM; checksum recorded | MSI + hash |
| Locked down | screen text is absent from logs and crash dumps | grep + review |

## 8. Risks

| Risk | Mitigation |
|---|---|
| UIA calls hang | per-call deadlines (1500 ms patterns, 700 ms properties) |
| `uiAccess` needs a signature and Program Files | plan the certificate early; refuse honestly without it |
| Two runtimes confuse support | one installer, one version number, one log file |
| IPC drift between C# and Kotlin | the frozen v1 file plus a round-trip test on both sides |
| The sidecar leaks secrets | Credential Manager only; the sidecar receives them in memory |
| Scope creep into a second product | the one rule in §1 |

## 9. Open decisions

- WinUI 3 after v0, or stay on WPF?
- SQLite in the sidecar: when does the JSON store stop being enough?
- Is the `uiAccess` helper a separate signed executable (recommended) or the main
  app signed with `uiAccess`?
- ~~Does the Windows client pair its own bridge token, or reuse the phone's?~~
  Resolved 2026-11-17: **its own** (ADR-0024). Device identity is carried
  explicitly in task/approval messages, never inferred from a shared credential.

## 10. Evidence carried over

The shell, the loop and the device adapter predate P0, and the Android branch
added prompt context that the sidecar now passes through. Their artifacts remain
valid and are linked here so nothing is lost:

| Artifact | What it proves |
|---|---|
| `docs/project/evidence/W0-spike.md` | the sidecar seam and one UI Automation click |
| `docs/project/evidence/W1-shell.md` | chat, persistence, settings and drafts |
| `docs/project/evidence/W2-loop.md` | the loop against a phone, approvals and records |
| `docs/project/evidence/W3-device.md` | the UIA adapter, its matrix and its failure taxonomy |
| `docs/project/evidence/W4-desktop.md` | tray, toast, shortcuts, attachments and voice |
| `docs/project/evidence/W5-package.md` | the packaged build and its hashes |
| `apps/windows/sidecar/src/main/kotlin/com/hopa/sidecar/turn/TurnEngine.kt` | the prompt names the Windows apps the catalog offers, marks `platform = "windows"`, and claims phone access only when a host is attached |
| `packages/core` (`TurnContext.vision`) | a frame can ride with a model call; the Windows host does not enable it yet, so the parity row stays `out` |
