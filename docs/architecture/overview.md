# HOPA architecture

## 1. Goals and constraints

HOPA observes a phone screen, decides on an action, executes it, verifies the
result, and records what happened. It must work with **other apps and websites**,
run untrusted user scripts **on-device in a WebAssembly sandbox**, and **never
complete a payment without explicit user confirmation**.

Constraints that shape the design:

- HarmonyOS NEXT (API 26) is sandboxed per app; there is **no ADB
  self-connection and no JVM** inside the app.
- **Accessibility and background / virtual-screen control are restricted** and
  require an ACL request + review. Plan a foreground-only fallback.
- Cross-app GUI automation therefore needs an **AccessibilityExtensionAbility**
  (and, for background screens, `ACCESS_VIRTUAL_SCREEN`) or the external
  `hopa-bridge` over `hdc` + `uitest` for development and evaluation.
- **Custom-drawn UIs** defeat a pure accessibility tree, so perception needs
  **accessibility tree + OCR + vision**.
- Irreversible actions (payment, send, delete) must be safe by construction.
- There is no Linux sandbox on-device; user scripts run in **Wasm (Pyodide /
  QuickJS)**, offline by default, with an explicit cloud fallback.

## 2. Layers

```
┌──────────────────────────────────────────────────────────────────────┐
│ entry/  (ArkUI shell)                                                │
│  Chat · Task progress · Floating capsule · Settings · Memory          │
│  Depends on core + capabilities. Contains no agent logic.             │
└───────────────▲──────────────────────────────────────────────────────┘
                │ observes run state / submits user intents / takeover
┌───────────────┴──────────────────────────────────────────────────────┐
│ core/  (plain ArkTS HAR, NO UI imports)                              │
│                                                                      │
│  AgentLoop ──► ModelClient (multi-provider; OpenAI-compatible first) │
│      │                                                               │
│      ▼                                                               │
│  ToolRegistry ──► ActionExecutor  (THE ONLY execution path)          │
│                        │                                             │
│                        ├─ 1. guards                                  │
│                        ├─ 2. payment approval  ◄── ApprovalPolicy    │
│                        ├─ 3. execute  ──► Capability                 │
│                        ├─ 4. verify                                  │
│                        └─ 5. record ──► RunStore (RunRecord)         │
└───────────────▲──────────────────────────────────────────────────────┘
                │ Capability interface (execute/observe)
┌───────────────┴──────────────────────────────────────────────────────┐
│ capabilities/  (independent HARs; may import core only)              │
│  web       ArkWeb browser: navigate, read, click, type               │
│  sandbox   hidden Web page + Pyodide/QuickJS (offline, cloud fallback)│
│  a11y      AccessibilityExtensionAbility (ACL)                       │
│  system    alarms, calendar, deep links                              │
└──────────────────────────────────────────────────────────────────────┘
```

Outside the app, for development and evaluation:

```
hopa-bridge (Python) ── hdc ──► emulator / phone
   │  dump layout, tap, type, swipe, screenshot, launch
   └─ CLI + MCP stdio server

bench (HOPA-Bench) ── uses hopa-bridge ──► scored tasks (5 now; 20 at M2; 50 at v2)
```

`hopa-bridge` is the **G1 PoC** control path. The shipping agent uses
`capabilities/accessibility` (once the ACL is granted), `capabilities/browser`, and
`capabilities/system`.

### 2.1 PC reference loop (`evals/baseline/`)

M1 runs the whole loop on the PC. `evals/baseline/` is the executable twin of `core/`:
same observation, action, policy, executor and record contracts, in Python.

| Module | Owns |
|---|---|
| `hopa_baseline.observation` | redaction, refs, truncation, hashing, schema |
| `hopa_baseline.actions` | action kinds and validation |
| `hopa_baseline.policy` | payment/sensitive/read classification |
| `hopa_baseline.executor` | the single execution path |
| `hopa_baseline.loop` | observe → decide → act → verify → record |
| `hopa_baseline.models` | stub and OpenAI-compatible clients |
| `hopa_baseline.records` | append-only hash-chained JSONL |

`hopa-baseline observe` is the reference observation producer. `hopa-bridge dump`
stays the raw `uitest` command. The ArkTS port follows the same contracts and
uses the same golden files (`contracts/schemas/`, `evals/baseline/tests/test_schemas.py`).

## 3. Perception: tree + OCR + vision

- Primary: accessibility tree / `uitest dumpLayout` (text, ids, bounds, roles).
- Fallback for custom-drawn canvases: OCR on the screenshot, then vision (model)
  to propose targets.
- Observations are redacted and hashed before being stored or sent to a model.
- Perception never executes; it only produces observations for the loop.

## 4. The action gate (`ActionExecutor`)

Every capability action — from the agent, a benchmark, a user macro, a scheduled
task, or a test — goes through `ActionExecutor.execute(action)`. There is no other
entry point.

```text
execute(action):
  1. guards(action)              // schema, allow-list, risk, preconditions
  2. payment approval            // if action.isPayment -> require user confirm
  3. outcome = capability.execute(action)
  4. verify(action, outcome)     // observe screen/state, compare to expectation
  5. record(RunRecord)           // append-only, includes approval decision
  return outcome
```

Rules:

- **Guard failure aborts** before any capability is touched.
- **Payment is fail-closed.** `ApprovalPolicy.requiresApproval(action)` returns
  `true` for anything classified as payment, and for actions that could *lead* to
  payment (opening checkout, entering card details, confirming an order). If
  classification is uncertain, it is treated as payment.
- A denied payment produces a `RunRecord` with `approved=false` and **no**
  execution. The agent must not retry through another path.
- `verify` may fail; the run record captures the actual observation, and the loop
  may replan. Verification never "fixes" a payment by itself.
- `record` is append-only. Editing/deleting a run record is a bug.
- **Human takeover** pauses the loop and hands control to the user (login, 2FA,
  payment). The gate resumes only after explicit hand-back.

### Action model (in `core/`)

```ts
class Action {
  id: string;
  kind: string;          // 'web.navigate' | 'ui.tap' | 'system.setAlarm' | ...
  target: string;
  text: string;
  url: string;
  x: number; y: number; toX: number; toY: number;
  // no isPayment field: the model may send one, the gate ignores it
}
```

The model may *propose* an action, but the executor owns payment
classification. A model cannot set or clear a payment class.

### Approval policy

`ApprovalPolicy` is the single source of truth:

- `payment` → always `ask` (never auto-approve, never "remember").
- `sensitive` (send message, call, delete, uninstall) → `ask`.
- unknown kind → `ask` (fail-closed).
- allow-listed read/benign UI actions → `allow` (still guarded and recorded).

## 5. Capability boundaries

Each capability is a separate HAR under `capabilities/`. They must not import each
other. Shared types live in `core/`.

### `web` — ArkWeb browser agent

- Owns the `Web` controller contract; the entry app hosts the `Web` component.
- Actions: `navigate(url)`, `read()`, `click(target)`, `type(target, value)`.
- Network is allowed only when the user enables it for the task. Downloads and
  file pickers require explicit approval.
- Does not know about payments; it raises observations and the executor classifies.

### `sandbox` — WebAssembly script runtime

- A **hidden** ArkWeb page that loads **Pyodide** (MPL-2.0) and **QuickJS** (MIT)
  from bundled `rawfile` assets; **offline by default**.
- No device APIs are exposed to scripts. Script I/O is a message channel to
  `core`.
- Network is off unless the user explicitly grants it; a **cloud fallback** is
  opt-in and logged.
- Hard limits: CPU timeout, memory cap, no persistent storage by default.

### `a11y` — AccessibilityExtensionAbility (restricted)

- Provides an accessibility service that can read the active window and inject
  gestures/text.
- **Depends on a restricted permission and an ACL request.** The extension is not
  declared in `module.json5` until the ACL is approved; the UI shows the
  capability as unavailable otherwise.
- The user must also enable the HOPA accessibility service in
  `Settings → Accessibility`.
- Background screens additionally need `ACCESS_VIRTUAL_SCREEN`; if it is not
  granted, fall back to foreground-only control.

### `system` — intents

- Alarm: create an alarm via the public Clock/`Want` route (preferred) rather than
  private APIs.
- Calendar: add an event through the calendar provider APIs (user-granted
  permission).
- Deep links: `openLink` / `startAbility` with an explicit `Want`; validate the URI
  scheme and host against an allow-list.

## 6. Permission / ACL dependency list

Levels follow the HarmonyOS permission model (`normal`, `system_basic`,
`system_core`, `user_grant`, `restricted`). **Confirm each exact level and ACL
requirement in the official permission list before requesting it**; this table is
the tracking list.

| Capability | Permission / capability | Level (confirm) | Notes |
| --- | --- | --- | --- |
| web | `ohos.permission.INTERNET` | normal | only when network is enabled |
| web | `ohos.permission.GET_NETWORK_INFO` | normal | connectivity checks |
| a11y | accessibility extension permission | restricted / ACL | **ACL request required**; user enables the service |
| a11y | `ohos.permission.ACCESS_VIRTUAL_SCREEN` | restricted / ACL | background screens; **ACL request + review** |
| system (calendar) | `ohos.permission.READ_CALENDAR`, `ohos.permission.WRITE_CALENDAR` | user_grant | prompt at first use |
| system (alarm) | prefer `Want` to the Clock app | — | avoid private alarm APIs |
| screenshots (in-app) | `ohos.permission.CAPTURE_SCREEN` (if used) | restricted | prefer external `hdc`/`uitest` for PoC |
| sandbox | none | — | offline; no device APIs exposed |

Extra ACL notes:

- The accessibility and virtual-screen capabilities likely need the app to be
  signed with a profile that includes the restricted permission (ACL). The exact
  permission strings and profile steps must be verified with Huawei before
  implementation.
- `hopa-bridge` does not need app permissions: it uses `hdc` + `uitest`, which the
  developer enables on the device.

## 7. Model client

`ModelClient` is an interface in `core/`:

```ts
interface ModelClient {
  complete(request: ModelRequest): Promise<ModelResponse>;
}
```

- Multi-provider, **OpenAI-compatible HTTP first** (`/v1/chat/completions`),
  configurable base URL, model, temperature, and API key.
- **Non-streaming today.** `complete()` waits for the full JSON response
  (`connectTimeout` 30 s, `readTimeout` 60 s). Streaming is a future change and
  must be documented here when it lands.
- The API key is held **in memory only** by `AgentService.configureModel`; it is
  not written to preferences and never logged. The Authorization header is the
  only place it is used. Persistent secure storage (Asset Store Kit / HUKS) is
  not implemented yet.
- A `StubModelClient` is used by tests and `bench` so the pipeline runs with no
  network.
- The model only proposes actions/plans; it never executes and never decides
  payment approval.

## 8. Run records and recovery

`RunRecord` is append-only and contains:

- run/task id, timestamps, app/package, model id;
- the proposed action and its classification;
- the approval decision (who/when, or `auto` for allow-listed reads);
- the raw observation before/after (layout hash + optional screenshot ref);
- verification result and error;
- a redacted trace for debugging (no secrets, no card numbers).

Records power the **Memory view**, the benchmark, scheduled-task recovery, and the
audit trail for the payment gate.

## 9. End-to-end example

```
user: "Order the usual coffee"
  └─ AgentLoop plans: open app → go to order → choose item → checkout
       └─ ActionExecutor.execute(Action(openApp))
            guards ok → not payment → capability.execute → verify → record
       ...
       └─ ActionExecutor.execute(Action(confirmOrder))
            guards ok → isPayment=true → ApprovalPolicy.ask
                 user taps "Approve" in the ArkUI sheet (or takes over)
            capability.execute → verify → record(approved=true)
       └─ ActionExecutor.execute(Action(pay))
            isPayment=true → ask again (never remembered) → ...
```

If the user denies any payment step, the loop stops that branch and reports it.
