# Data flow

One goal moves through the system in one direction. Every arrow below is a
function call you can find by name.

```
goal
  │
  ▼
PromptBuilder ──▶ ModelClient ──▶ ActionParser
  ▲                                   │
  │                                   ▼
Screen ◀── ScreenSource        ActionExecutor (gate)
  ▲                                   │
  │                                   ▼
  └──────── Observation ◀──── capability (accessibility | browser | llm | sandbox | system)
                                          │
                                          ▼
                                      RunRecord ──▶ RunStore
```

## The happy path

| Step | File | What it does |
|---|---|---|
| 1. capture | `entry/services/CompositeScreenSource.ets` | PC bridge, else accessibility, else browser text; returns a `Screen` |
| 2. prompt | `core/agent/PromptBuilder.ets` | system rules + memory + skill + deterministic router suggestion + known apps/sites + screen text and element refs |
| 3. model | `capabilities/llm/*` behind `core/model/ModelClient.ets` | one request, one `ModelResponse` |
| 4. parse | `core/agent/ActionParser.ets` | JSON to `Action`; plain text is a final answer |
| 5. gate | `core/gate/ActionExecutor.ets` | guards, then `ApprovalPolicy` (payment always asks), then the owning capability |
| 6. act | `capabilities/*` | taps, types, navigates, launches |
| 7. verify | `core/gate/ActionExecutor.ets` | re-observe and compare; a failed action stops the loop |
| 8. record | `core/runs/RunStore.ets` | append-only `RunRecord` with status, approval and duration |
| 9. repeat | `core/agent/AgentLoop.ets` | feed the observation back, up to `maxSteps` |

`AgentLoop` orchestrates 2-9. It does not know how to tap, how to call a model
or how to persist anything.

## The approval path

```
Action ─▶ ApprovalPolicy.classify ─▶ Payment? ─ yes ─▶ ApprovalGateway (always asks, never remembered)
                                        │
                                        └─ no ─▶ autonomous? ─ yes ─▶ execute
                                                          └─ no ─▶ Read? ─ yes ─▶ execute
                                                                            └─ no ─▶ ask
```

The UI installs the prompt handler in `entry/pages/chat/ChatPage.ets`; until it does,
`UiApprovalGateway` denies everything. A denied action still produces a
`RunRecord` with status `denied`.

## Background and scheduled runs

```
ScheduleService timer ─▶ due task ─▶ AgentRuntime.run(goal)
                                        │
                                        └─▶ BackgroundKeeper.begin()  (only when the bridge is configured)
                                              │
                                              └─▶ the same loop as above
```

A schedule is in-app only: the HarmonyOS reminder agent rejects this emulator.
The timer lives in `entry/services/ScheduleService.ets`; the run lives in
`AgentService`.

## Tethered control

```
entry services/BridgeClient ──HTTP──▶ services/pc-agent api/bridge.py
        │                                     │
        │                                     ├─ hdc dumpLayout ─▶ Layout
        │                                     └─ hdc tap / type / launch
        ▼
entry/services/BridgeUiCapability.ets (screen source + ui actions)
```

The bridge is the active backend when one is configured: the accessibility
capability stands down, so a ref from the bridge is never executed by the
on-device gesture code.

## Persistence map

| Data | Owner | Store |
|---|---|---|
| facts, skills, runs | `entry/services/*Store.ets`, `RunArchive.ets` | preferences (`hopa_settings`) |
| conversations | `entry/pages/Index.ets` (target: `ConversationService`) | preferences (`chats_v1`) |
| schedules | `ScheduleService` | preferences (`schedules_v1`) |
| settings | `SettingsStore` | preferences (no API key) |
| exports | `ExportService` | `filesDir/hopa-export.json` |

Secrets: the model API key is memory-only; the bridge URL and token are stored
so a tethered session survives a restart.
