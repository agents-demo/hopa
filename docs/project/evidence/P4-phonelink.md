# P4 — phone link

Date: 2026-11-19. Decision: ADR-0024 (Windows pairs its own backend credential;
device identity and task state come from the gateway, never from a shared token
or a client-supplied role).

Status: **P4 code complete; the hardware gate remains to be run.** The Windows
host owns its own gateway pairing and socket, a PC action can ask the phone to
approve it, and the run record names the device that answered. The backend now
accepts the approval request that the week-1 plan had reserved; role routing and
signed household decisions remain the week-5 work described in the backend plan.

## The wire

An approval is a task, not a second queue:

```text
PC                                      backend                         phone
 | task.create (optional handoff)          |                               |
 |---------------------------------------->| route / queue / wake          |
 |                                         |------------------------------>|
 |                                         |                               |
 | task.needs_approval {goal, approval}     |                               |
 |---------------------------------------->| task state needs_approval     |
 |                                         |------------------------------>|
 |                                         |                      approval sheet
 |                                         |                               |
 |                                         |<------------------------------|
 |                                         |       task.result             |
 |<----------------------------------------|       {approval:{allow}}      |
 | execute or stop; record approver=phone  |                               |
```

`task.needs_approval` carries the same `ApprovalRequest` fields the local sheet
uses: title, body, amount, merchant, consequence, `isPayment` and the action. A
phone answer is `task.result` with `{"approval":{"allow":true|false}}`. The
server sets `from`; the client never names another device.

## What landed

| Thing | Where |
|---|---|
| `task.needs_approval` in the gateway schema, validator, router and store | `contracts/schemas/gateway.v1.schema.json`, `services/backend/.../EnvelopeValidator.kt`, `TaskRouter.kt`, `TaskStore.kt`, `PgTaskStore.kt` |
| `needs_approval` is a durable task state; offline phones receive it on hello, and delivery keeps the request type | `TaskRouter.deliver`, `TaskStore.pendingFor`, `V5__task_needs_approval.sql` |
| Windows owns its own pairing: `hopa://pair` → `/v1/pair/claim`, `platform=windows`, its own key, Credential Manager | `apps/windows/Hopa.Windows/Gateway/GatewayClient.cs`, `Storage/CredentialStore.cs` |
| Windows gateway socket: `device.hello`, presence, `task.create`, `task.needs_approval`, `task.result`, refresh on auth close | `GatewayClient.cs` |
| The host asks the phone before the local sheet; a timeout or dead link denies | `MainWindow.OnApprovalRequested`, `HostApproval` |
| The sidecar only learns whether a phone peer is reachable; a phone claim without that link is refused | `RuntimeConfig.hasPhoneLink`, `Main.kt` `approval.result`, `EngineHostClient.SendGatewayState` |
| Android shows the same approval sheet for a remote request and returns the decision | `apps/android/app/.../RemoteApprovalRunner.kt`, `BackendClient.onApproval`, `AppContainer` |
| Approval provenance on the record | `Approver`, `ApprovalDecision`, `RunRecord.approver`, `Protocol.step` |
| A dropped link or a late answer is a denial, never a silent yes | `RemoteApprovalRunner` timeout, `HostApproval` timeout, `TaskStore.failLink` |

## Settings

**Windows → Settings → Phone link** takes the `hopa://pair?...` link and pairs
this PC. The link is claimed once; the token pair is stored in Windows
Credential Manager, never in the app's JSON settings.

## Tests

| Suite | What it proves |
|---|---|
| `TaskRoutingTest` (backend) | an approval reaches the phone and its result returns to the PC |
| `RemoteApprovalRunnerTest` (Android) | a request is acked, the sheet is asked once, and allow/deny becomes a `task.result` |
| `TaskStoreTest` (sidecar) | `needs_approval` is a state; a result names its approver |
| `ApprovalProvenanceTest` (core) | pc/phone provenance is recorded; a denial keeps the source |
| `GatewayCodecTest` / fixture check | the new message type is accepted by the schema and codec |

Commands used:

```powershell
.\apps\android\gradlew.bat -p services\backend :test --no-daemon
.\apps\android\gradlew.bat -p apps\windows\sidecar test --no-daemon
.\apps\android\gradlew.bat :app:testDebugUnitTest --no-daemon
cd apps\windows\Hopa.Windows; dotnet build -c Debug
python tools\checks\check-gateway-fixtures.py
```

## Limits left for the backend's week 5

1. **Role routing.** The request goes to the paired peer; choosing a parent or
   guardian by household role is week-5 work.
2. **Signed decisions.** The backend attributes the answer to the authenticated
   socket. A device-key signature over the decision is not added yet.
3. **Key wrapping.** Pairing enrolls the PC's public key, but payload encryption
   and household-key wrapping remain the week-2/week-6 contract.
4. **Incoming task execution UI.** A phone-originated `task.create` is delivered
   to the host and logged; the general task inbox is not part of P4.
