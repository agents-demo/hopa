# Layers and dependencies

HOPA has three layers. The arrows only point one way.

```
entry  ──▶  capabilities  ──▶  core
  │                               ▲
  └──────────────▶────────────────┘
```

| Layer | May import | Must not import | Examples |
|---|---|---|---|
| `core` | ArkTS standard library only | any `@kit.*`, any capability, any page | `AgentLoop`, `ApprovalPolicy`, `ChatHistory` |
| `capabilities` | `@hopa/core`, its own OS kit | another capability, `entry` | `BrowserCapability`, `AccessibilityBridge`, `OpenAiClient` |
| `entry` | `core`, every capability, OS kits | nothing above it | pages, navigation, services |

`tools/checks/check-structure.py` enforces the table. It is a report today and
will become `--strict` in CI when the page split is finished.

## Core is pure

`core` must be testable without a device, a UI or a network. That is why:

- the HTTP model clients live in `capabilities/llm`, not in `core/model`;
- `core/model` only defines `ModelClient`, `ModelRequest`, `ModelResponse`;
- `Screen` is text and bounds, not a screenshot;
- `ApprovalPolicy` classifies an action from text, not from a UI dialog.

If a change needs `@kit.NetworkKit`, it belongs in a capability. If it needs an
ArkUI type, it belongs in `entry`.

## Capabilities are leaves

A capability answers one question and does not call another capability:

| Capability | Answers | Does not |
|---|---|---|
| `accessibility` | what is on screen and how to tap it | decide whether tapping is allowed |
| `browser` | read, click and type on a web page | launch apps |
| `llm` | send one model request | choose the model or keep the key |
| `sandbox` | run an isolated script | open the network |
| `system` | start a system intent | record the outcome |

Cross-capability work happens in `entry`, which is the composition root.

The bridge client (`BridgeClient` + `BridgeUiCapability`) stays in
`entry/services` because it must know whether accessibility is the preferred
backend, and a capability may not import another capability. When the bridge is
preferred it also owns `ui.launch`: the PC can start an ability while HOPA is in
the background. Without a bridge, the local `AppLauncher` launches.

## Entry is the only place that wires things

`entry` owns the running app and is allowed to know every layer:

- `services/AgentService.ets` is the composition root. It builds the executor,
  the capabilities and the runtime once, and exposes narrow delegates.
- `services/AgentRuntime.ets` owns the loop, the model, the last-run facts and
  the batch. It has no UI and no persistence.
- `services/*` are one concern each: conversations, schedules, runs, export,
  settings, approvals, bridge, model factory, logging.
- `navigation/` (the sheet and bottom bar) and `pages/<area>/` render; they never build a
  loop or a model client.

## Where does a new thing go?

| The new thing is... | Put it in... |
|---|---|
| a value type (action, observation, record) | `core/src/main/ets/domain/` |
| a rule for allow / deny / ask | `core/src/main/ets/gate/` |
| how to read or act on a phone app | `capabilities/accessibility/` |
| how to read or act on a web page | `capabilities/browser/` |
| a provider HTTP adapter | `capabilities/llm/` |
| persistence for one kind of data | `entry/services/` |
| a screen | `entry/pages/<area>/` |
| a reusable visual row or card | `entry/components/` |
| a route or shell entry | `entry/navigation/` |
| a build or release step | `tools/scripts/` |
| a rule that keeps this shape | `tools/checks/` |

## Anti-patterns the structure rejects

- `utils/`, `helpers/`, `common/`, `misc/` - no owner, no boundary.
- A capability importing another capability because "it was easier".
- A page constructing an `AgentLoop` or a `ModelClient`.
- `core` importing `@kit.*` for one HTTP call.
- `Index.ets` used as a catch-all file. Only package barrels and the ArkUI
  entry page may be named `Index.ets`.
- A file that is both a model and a screen.
