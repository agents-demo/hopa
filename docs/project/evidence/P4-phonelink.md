# P4 — phone link (in progress, aligned to the backend gateway)

Date: 2026-11-17. Decision: ADR-0023 (Windows pairs its own backend credential;
device identity and task state come from the gateway, never from a shared token
or a client-supplied role). This supersedes the earlier relay-based draft after
upstream added `services/backend` (ADR-0022).

This file records the part of P4 that has landed: the first checkbox (task
messages) and the record-contract groundwork for approval provenance. The phone
approval transport itself is **not** done: the gateway reserves
`task.needs_approval` until backend week 5, and there is no Windows gateway
client yet. The remaining three P4 checkboxes stay open.

## Alignment with the gateway

| Local (Windows IPC) | Backend gateway | Where |
|---|---|---|
| `task.start` / `task.get` / `task.list` / `task.handoff` | local view of `task.create` | `TaskStore.kt`, `Main.kt` |
| `task.event` | `task.ack` / `task.progress` / `task.result` / `task.error` / `task.cancel` | `Main.kt` |
| `queued → delivered → acked → progress → done / failed / cancelled` | same states | `TaskRouter.kt:215–221` |
| `from`/`to` = `pc`/`phone` | server-set `deviceId`, `platform = windows\|android` | `gateway.v1.schema.json:44–51` |
| `approver.device = pc\|phone` | `platform` (`windows → pc`, `android → phone`) | `Approver.fromPlatform` |

The backend's Postgres task store is authoritative. `TaskStore` is only a local
projection, rebuilt from gateway events; it does not invent a second state
machine. The host maps IPC messages to and from `Envelope` frames and sets
`approval.result.device` from the authenticated gateway sender.

## What landed

| Thing | Where |
|---|---|
| ADR-0023, gateway-aligned resolution of the plan's open token question | `docs/design/decisions/0023-windows-device-identity-and-approval.md` |
| `task.start`, `task.get`, `task.list`, `task.handoff`, `task.event` | `apps/windows/sidecar/.../TaskStore.kt`, `Main.kt`, `Protocol.kt`, `protocol.md` |
| `approver: {device, at}` on the run record | `contracts/schemas/run-record.schema.json`, `docs/reference/contracts/run-record.md`, `RunRecord`, `RunRecordDraft`, `RunRecordFactory`, `RunChain`, `RunRecordSerializer` |
| An approval answer carries its source device | `ApprovalDecision`, `ApprovalGateway.decide`, `HostApproval.resolve`, `approval.result.device`, `Protocol.step.approver` |
| Fail-closed provenance: no bridge means no phone approval | `Main.kt` `approval.result` handler |
| Gateway states/events and the `platform → device` mapping | `TaskStore`, `Approver.fromPlatform` |

## Task messages (real NDJSON transcript)

```
host -> {"type":"hello"}
sidecar -> {"type":"ready","version":1}
host -> {"type":"task.start","id":"a","taskId":"t-1","goal":"open notepad","device":"pc"}
sidecar -> {"type":"task.start","id":"a","ok":true,"task":{"id":"t-1","goal":"open notepad","state":"queued","from":"pc","events":[{"index":0,"type":"task.create","from":"pc","at":…}]}}
host -> {"type":"task.handoff","id":"b","taskId":"t-1","target":"phone"}
sidecar -> {"type":"task.handoff","id":"b","ok":true,"task":{… "to":"phone", "state":"queued" …}}
host -> {"type":"task.event","id":"c","taskId":"t-1","event":"deliver","from":"phone"}
sidecar -> {"type":"task.event","id":"c","ok":true,"task":{… "state":"delivered", "events":[…{"type":"deliver","from":"phone"}…] …}}
host -> {"type":"task.event","id":"d","taskId":"t-1","event":"task.result","from":"phone","platform":"android"}
sidecar -> {"type":"task.event","id":"d","ok":true,"task":{… "state":"done", "events":[…{"type":"task.result","from":"phone"}…], "approver":{"device":"phone","at":…} …}}
```

No step claims a result the target has not reported: `task.handoff` records the
target but leaves the state at `queued`, and a result event is required to reach
`done`. An invalid target or event is refused with `E_SCHEMA`, never silently
accepted.

## Approval provenance

- `ActionExecutor` asks `ApprovalGateway.decide()` once, before any tier runs.
  The returned `ApprovalDecision(device)` is written to the step as
  `approver: {device, at}`; a gateway that has not been taught about the phone
  keeps its old behaviour (`pc`).
- `approval.result` accepts `device: "pc" | "phone"`, which the host must set
  from the authenticated gateway `from`. A phone allow is refused when no bridge
  is attached, because there is no path by which the phone could have answered.
  This is fail-closed, not proof of source.
- `Protocol.step` carries `approver`, so the rail can name the device before
  `turn.end`.

## Tests

| Suite | Tests | Coverage |
|---|---|---|
| `ApprovalProvenanceTest` (core) | 4 | phone/pc named on the record, denial keeps the device, no approval means no approver |
| `TaskStoreTest` (sidecar) | 11 | gateway states/events, target validation, fail-link, platform mapping, frozen shape on the wire |
| `ProtocolTest` (sidecar) | 6 | `step.approver`, v1 task refusal still available |

## What is deliberately not done

1. A **Windows gateway client** in the C# host (WebSocket `Envelope` codec,
   pairing, token storage) that maps IPC `task.event` to real gateway frames.
2. **Approval over the gateway.** `task.needs_approval` is reserved and refused
   with `E_UNSUPPORTED` until backend week 5; signed device-key decisions land
   there. Do not invent a gateway message that the server will reject.
3. **Real source authentication** on `approval.result.device`: today the sidecar
   trusts the host's label and only fails closed without a bridge. It cannot yet
   prove the sender is the phone.
4. Wire link-loss from the gateway client into `TaskStore.failLink`.

Until those land, the three remaining P4 checkboxes stay unchecked. Doing
otherwise would record an approval as coming from the phone when nothing proves
it did.
