# Restructure Windows apps

Deep critique and proposed new structure for
`apps/windows/sidecar/src/main/kotlin/com/hopa/sidecar` and
`apps/windows/Hopa.Windows`.

This is a plan, not a single change. Renames are PR 1 (mechanical, no behaviour
change). The MainWindow refactor is PR 2 (architectural).

> **Status (2026-11-23):** partly adopted. The safe renames, the avatar
> rename and the first testable UI rules landed in `refactor/naming`; the
> architectural MainWindow split is a separate project. The decision record
> is at the end of this file.

---

## Kotlin sidecar (`com.hopa.sidecar`)

### Package naming issues

#### `turn/` is the wrong name for the core engine package

The package contains `Engine`, `RuntimeConfig`, `TurnOutcome`, `SystemClock`,
`TurnRecorder`, `ScriptedModel`, `SidecarCatalog`. It owns the sidecar's main
orchestration logic — the agent loop, coroutine supervision, turn serialization,
cancellation. "Turn" is too narrow a name for all of this. Rename to `engine/`.

#### `backend/` collides with `core/backend`

`com.hopa.sidecar.backend` shadows the shared `com.hopa.backend` module in
imports and in the reader's mental model. The Android plan chose `link/` for
exactly the same reason (the app module already has `core/backend` and
`services/backend`). Same fix here: rename `backend/` → `link/`.

#### `protocol/` conflates three distinct concerns

| File | Concern |
|---|---|
| `Protocol.kt` | Message schema / NDJSON factory |
| `Stdio.kt` | I/O transport |
| `Dispatcher.kt` + `handlers/` | Message routing and application logic |

The first two are infrastructure; the third is application-layer wiring. Calling
the folder `wire/` ("wire format" is already project vocabulary) is more precise
than `protocol/`. The `handlers/` subpackage becomes `handler/` (singular, as
used elsewhere in the codebase).

### Class naming issues

#### `SidecarKnowledge` still uses the old terminology

The `knowledge → catalog` rename did not reach the sidecar. Rename to
`SidecarCatalog`.

#### `StubModel` is not a stub — it is a scripted model

A stub returns empty/null. `StubModel` returns **scripted, deterministic answers**
used for headless single-turn runs (`--turn` mode). It is production code, not a
test double. The name misleads. Rename to `ScriptedModel`.

#### `WindowMode.kt` → `ProtocolMode.kt`

"Window" here means "running with a host UI window" (vs headless). It has nothing
to do with a widget. The entry function is already `runProtocol`. The file name
should match.

#### `BackendPairing` in the sidecar collides with `com.hopa.backend.BackendPairing`

The core module has a `BackendPairing` for the shared admission protocol. The
sidecar has another `BackendPairing` that orchestrates the client-side admission
flow: encodes the QR code, renders PNG and Unicode, persists the session. These
are two different classes with the same name. Rename the sidecar one to
`BackendAdmission`.

### Proposed sidecar structure

```
com.hopa.sidecar/

Main.kt

cli/
  CliOptions.kt
  Paths.kt
  Usage.kt
  ProtocolMode.kt        ← was WindowMode.kt
  HeadlessMode.kt

engine/                  ← was turn/
  SidecarEngine.kt       ← was Engine.kt
  TurnOutcome.kt
  RuntimeConfig.kt
  SystemClock.kt
  TurnRecorder.kt
  ScriptedModel.kt       ← was StubModel.kt
  SidecarCatalog.kt      ← was SidecarKnowledge.kt

wire/                    ← was protocol/
  Protocol.kt
  Stdio.kt
  Dispatcher.kt
  handler/               ← was handlers/
    MessageHandler.kt
    ConversationHandler.kt
    TurnHandler.kt
    ConfigHandler.kt
    DeviceHandler.kt
    FileHandler.kt
    TaskHandler.kt
    ApprovalHandler.kt
    BackendHandler.kt

link/                    ← was backend/
  BackendAdmission.kt    ← was BackendPairing.kt
  BackendSessionStore.kt
  BackendGateway.kt
  GatewayHost.kt
  EngineTaskRunner.kt
  ContentKey.kt
  QrRender.kt

store/
  ChatStore.kt
  RecordStore.kt
  TaskStore.kt
  PendingApprovals.kt
  Attachments.kt

device/
  HostDevice.kt
  HeadlessDevice.kt
  HostSystem.kt
  WindowsIntents.kt
  WindowsPathSelector.kt

approval/
  HostApproval.kt
  DenyAllApproval.kt
```

---

## C# app (`Hopa.Windows`)

### Package naming issues

#### `Engine/` is the wrong name

`EngineHostProcess` and `EngineHostClient` are the sidecar's process manager and
NDJSON protocol client — from the C# side, they are a **client** to the Kotlin
engine, not the engine itself. Naming the package `Engine` implies ownership of
the intelligence; the C# side only owns the subprocess bootstrap and the
protocol layer.

Rename `Engine/` → `Sidecar/` and the classes inside it:

| Current | Proposed |
|---|---|
| `Engine/EngineHostProcess.cs` | `Sidecar/SidecarProcess.cs` |
| `Engine/EngineHostClient.cs` | `Sidecar/SidecarClient.cs` |
| `Engine/TurnResult.cs` | `Sidecar/TurnResult.cs` |

#### `Gateway/` has the same problem as Android

The backend link is not a "gateway." The Android plan renamed `gateway/` → `link/`
for this reason. Same fix:

| Current | Proposed |
|---|---|
| `Gateway/GatewayCredentials.cs` | `Link/LinkCredentials.cs` |
| `Gateway/GatewayClient.cs` | `Link/LinkClient.cs` |
| `Gateway/GatewayPairing.cs` | `Link/LinkPairing.cs` |

#### `HopaMark` — clarify before renaming

The exploration describes it as "plush animated HOPA mark control; idle animation
(float, breathe, blink), static mode for performance." If it is the animated HOPA
mascot/logo: rename to `HopaAvatar`. If its primary role is rendering markdown:
`MarkdownView`. The right name depends on what the control actually displays in
the app — confirm before the rename.

### Architectural issue: `MainWindow` is a god class in disguise

`MainWindow` is split into six partial files (`Chat`, `Checks`, `Composer`,
`EngineRequests`, `RunRail`, `Sidebar`). That split defers the problem rather than
solving it. The partial class mechanism was designed for XAML designer-generated
code — using it to manage a class too large to fit in one file is a code smell.

The partial split does not reduce coupling: every partial still shares the same
fields (`client`, `device`, `voice`, `gateway`, `conversations`, `messages`,
`currentId`, `running`, …). Any partial can read and mutate any state. This is the
same god-class problem as `SettingsViewModel` on Android.

Fields visible in `MainWindow.xaml.cs`:
`conversations`, `allConversations`, `messages`, `drafts`, `log`, `device`,
`voice`, `speech`, `tray`, `client`, `gateway`, `currentId`, `lastSteps`,
`pendingAttachment`, `autoApproval`, `outputPath`, `switching`, `running`,
`lastQuestion`, `lastAnswer`

That is at least five independent state machines sharing one object.

The modern WPF fix is the same as the Android fix: one ViewModel per pane, each
pane becomes a `UserControl`, the partials disappear.

| Current partial | Becomes |
|---|---|
| `MainWindow.Sidebar.cs` | `ConversationsViewModel` + `ConversationList` UserControl |
| `MainWindow.Chat.cs` | `ChatViewModel` + `ChatPane` UserControl |
| `MainWindow.Composer.cs` | Part of `ChatViewModel` + `Composer` UserControl |
| `MainWindow.RunRail.cs` | `RunRailViewModel` + `RunRail` UserControl |
| `MainWindow.EngineRequests.cs` | stays in MainWindow (lifecycle, approval routing) |
| `MainWindow.Checks.cs` | stays in MainWindow or moves to Shell startup logic |

After the split, `MainWindow` owns: `SidecarClient` lifecycle, window chrome,
tray icon, routing of sidecar events to the correct ViewModel. Nothing else.

This is not mandatory to do alongside the renames, but the architectural issue
grows linearly as new features are added.

---

## Priority order

### PR 1 — renames, no behaviour change

**Kotlin sidecar:**
1. `turn/` → `engine/`; `Engine.kt` → `SidecarEngine.kt`
2. `backend/` → `link/`; `BackendPairing.kt` → `BackendAdmission.kt`
3. `protocol/` → `wire/`; `protocol/handlers/` → `wire/handler/`
4. `WindowMode.kt` → `ProtocolMode.kt`
5. `SidecarKnowledge.kt` → `SidecarCatalog.kt`; class renamed to `SidecarCatalog`
6. `StubModel.kt` → `ScriptedModel.kt`; class renamed to `ScriptedModel`

**C#:**
7. `Engine/` → `Sidecar/`; rename all three classes
8. `Gateway/` → `Link/`; rename all three classes
9. `HopaMark` → `HopaAvatar` or `MarkdownView` — clarify first

Every move is a find-and-replace rename; nothing here changes wire format or
behaviour.

### PR 2 — MainWindow refactor

10. Extract `ConversationsViewModel` (sidebar state: conversation list, search,
    pin/archive, selection, rename)
11. Extract `ChatViewModel` (messages, turn state, attachment, cancel)
12. Extract `RunRailViewModel` (run steps, narration display)
13. Each concern becomes a `UserControl` with its own ViewModel binding
14. `MainWindow` becomes the shell: hosts the three controls, owns
    `SidecarClient` lifecycle, routes approval and device events, nothing else
15. Add unit tests for ViewModel logic that is currently untestable inside the
    partial class (search filtering, message grouping, step formatting)

---

## What was adopted, and what was not (2026-11-23)

Adopted:

- Kotlin: `SidecarKnowledge` -> `SidecarCatalog`, `StubModel` -> `ScriptedModel`,
  `WindowMode.kt` -> `ProtocolMode.kt`, sidecar `BackendPairing` ->
  `BackendAdmission`, `protocol/handlers/` -> `protocol/handler/`.
- C#: `HopaMark` -> `HopaAvatar`.
- First testable UI rules: `ConversationRow`, `RunStepRow` and
  `ConversationFilter` now have unit tests; the sidebar filter is a pure class,
  not window state.
- `RunRailView` + `RunRailViewModel`: the right rail is a `UserControl` with its
  own view model and four tests; the window no longer writes `RailTitle`,
  `RailSteps` or the bridge line.
- `ConversationsView` + `ConversationsViewModel`: the sidebar list, search,
  archive switch, selection and context-menu actions are a control with four
  more tests. The window only handles the engine calls and dialogs.
- `ChatView` + `ChatViewModel`: the bubbles, answer actions, error, attachment
  and composer are a control with five tests. The window still starts the turn,
  routes approval/device events and owns the client; the pane renders the model.
- The pane and controller tests cover rows, filters, attachments, drafts, turn
  reports and errors; the client suite is 40.

Not adopted, with reasons:

- `turn/` -> `engine/`: kept `turn/`. `core/agent/turn` already uses the word,
  Android has `engine/llama`, and `engine/` inside "engine host" reads as a
  recursion. The package does more than one turn, but `turn` is still the
  product word.
- `protocol/` -> `wire/`: kept `protocol/`. It is the documented wire contract,
  and routing already has its own `handler/` package. A split into `wire/` +
  `dispatch/` is only worth it when routing grows.
- `backend/` -> `link/` and `Gateway/` -> `Link/`: kept `backend/` and
  `Gateway/`. `backend` is an accepted HOPA term, and the proposed structure
  still kept `BackendGateway` inside `link/`. Move to `link` only when every
  client (Android and Windows) does it together.
- MainWindow -> ViewModels and UserControls: done for the three panes
  (`Panes/RunRailView`, `Panes/ConversationsView`, `Panes/ChatView`).
  `ChatController` now owns send/select/create and the running flag; the window
  keeps lifecycle, chrome, tray, client and event routing.
- `MainWindow.Checks.cs` is split by family: `MainWindow.Headless.cs` (turn and
  list modes, screenshots), `MainWindow.Screenshots.cs` (W4/W6 and the controls)
  and `MainWindow.Checks.cs` (engine and bridge checks).
