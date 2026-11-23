# HOPA sidecar (engine host)

The Kotlin process behind `Hopa.Windows`. The window starts it and speaks
NDJSON over stdin/stdout; `Protocol.VERSION` is `1`.

It owns the shared agent loop for this host, the conversation and record
stores, the approval gate, this PC's device adapter, and the backend admission
and link. It is not a second brain: the loop, the decision policies and the
graph live in `core/`.

## Layout

| Folder | What the reader finds |
|---|---|
| `cli/` | how the process starts: `CliOptions`, `Usage`, `Paths`, `HeadlessMode`, `ProtocolMode` |
| `protocol/` | the wire: `Protocol` (version and envelopes), `Stdio`, `Dispatcher` |
| `protocol/handler/` | one message family per class, behind `MessageHandler` |
| `turn/` | one turn: `Engine`, `TurnOutcome`, `TurnRecorder`, `RuntimeConfig`, `ScriptedModel`, `SidecarCatalog`, `SystemClock` |
| `device/` | this PC as a device: `HostDevice`, `HeadlessDevice`, `HostSystem`, `WindowsIntents`, `WindowsPathSelector` |
| `store/` | what lives on disk: conversations, records, tasks, pending approvals, attachments |
| `backend/` | the backend link: `BackendAdmission`, `BackendGateway`, `BackendSessionStore`, `GatewayHost`, `EngineTaskRunner`, `ContentKey`, `QrRender` |
| `approval/` | who allowed an action: `HostApproval`, `DenyAllApproval` |

## Message families

| Messages | Handler |
|---|---|
| `conversations.*`, `conversation.*` | `ConversationHandler` |
| `turn.start`, `turn.cancel` | `TurnHandler` |
| `file.attach`, `file.remove` | `FileHandler` |
| `configure` | `ConfigHandler` |
| `task.*` | `TaskHandler` |
| `device.result`, `gateway.state` | `DeviceHandler` |
| `approval.result` | `ApprovalHandler` |
| `backend.pair` | `BackendHandler` |
| `hello`, `shutdown`, unknown | `Dispatcher` |

## Run

```powershell
# from apps/android
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon
.\gradlew.bat -p ..\windows\sidecar test --no-daemon
```

The window finds the installed library next to the app, or in the build tree
when run from a checkout. `HOPA_SIDECAR_LIB` overrides the location.

## Headless

```powershell
java -cp "apps/windows/sidecar/build/install/hopa-windows-sidecar/lib/*" `
  com.hopa.sidecar.MainKt --turn "say hello"
```

Headless is deterministic by construction: no model key is loaded, so the
engine uses `ScriptedModel`, and no host is attached, so approvals deny and
actions refuse. `--data-dir` and `HOPA_DATA_DIR` choose where conversations and
records go.

The full flag list is in `cli/Usage.kt`; unknown flags fail closed.

## Stability

Message names, fields and `Protocol.VERSION` are read by `Hopa.Windows`. They
are a wire contract: rename code freely, but changing a message is a protocol
change.
