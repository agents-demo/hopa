# P1 — the engine runs headless through the real gate

Date: 2026-11-16. Host: Windows, JDK 17 toolchain (Temurin 17.0.21), Gradle 8.11.1.
Protocol v1 ([`docs/project/plan/windows/protocol.md`](../plan/windows/protocol.md)).

Merged onto `033162b` (the Android parity branch). That branch's only sidecar
delta was prompt context in `Engine`: `platform = "windows"`, the catalog's
Windows app list, and `phoneAccess`. All three are preserved; headless passes
`phoneAccess = false` because no host is attached.

## What this proves

1. The sidecar boots the **real** `AgentLoop` and the **real** `ActionExecutor`
   from `packages/core`; nothing is re-implemented in the host.
2. A plain turn answers, writes no record, and verifies the (empty) chain.
3. A payment is **refused before the device is touched**: `approved=false`,
   `executed=false`, `error=E_REFUSED`.
4. A benign action still runs, so the refusal is specific, not a blanket stop.
5. With no host attached, an action fails **honestly** (`E_UNSUPPORTED`) instead
   of pretending to succeed.
6. Conversations and records survive a reload.
7. `task.*` is refused with a readable error, never silently ignored.

P1 also renames the old `SpikeModel` to `StubModel` and deletes the allow-all
`SpikeApproval`; earlier evidence files keep the old names because they describe
the commits in which those classes existed.

## Tests

`apps/android> .\gradlew.bat -p ..\windows\sidecar test --no-daemon`

| Suite | Tests | Failures |
|---|---|---|
| `ChatStoreTest` | 4 | 0 |
| `HeadlessTurnTest` | 7 | 0 |
| `PendingApprovalsTest` | 2 | 0 |
| `ProtocolTest` | 5 | 0 |
| `RecordStoreTest` | 2 | 0 |
| `StubModelTest` | 5 | 0 |
| **Total** | **25** | **0** |

`HeadlessTurnTest` is the P1 gate. Its seven cases are: a plain turn, a denied
payment, a read action that reaches the device, a launch, the headless device's
refusal, a second turn on the same conversation, and the envelope shape.

`ProtocolTest` freezes the two new shapes (`step`, `task.error`) and rejects an
unknown CLI option.

## `--turn "say hello"`

```
[sidecar] turn cli-1 in c-14c384e6-238d-4ad7-97dc-341fc0fa78b7: say hello
{"type":"turn.end","id":"cli-1","conversationId":"c-14c384e6-238d-4ad7-97dc-341fc0fa78b7","title":"say hello","answer":"Stub answered: \"say hello\".","chainOk":true,"error":null,"records":0,"executed":0,"denied":0,"steps":[],"narration":[]}
[sidecar] headless turn done: records=0 approvals=0 chainOk=true
```

## `--turn "pay 100 for the order"` (the deny path)

```
[sidecar] turn cli-1 in c-79a3b9f4-72b9-4e98-b5f7-5f690de2ff2d: pay 100 for the order
{"type":"turn.end","id":"cli-1","conversationId":"c-79a3b9f4-72b9-4e98-b5f7-5f690de2ff2d","title":"pay 100 for the order","answer":"I did not run that.","chainOk":true,"error":null,"records":1,"executed":0,"denied":1,"steps":[{"schemaVersion":"1","runId":"run-cli-1","step":0,"timestamp":"2026-11-15T16:15:00.943Z","traceId":"a1af3b44-a12f-4277-bf6f-beeb24bf1404","action":{"schemaVersion":"1","kind":"payment.pay","text":"100","app":"bank","timeoutMs":3000},"classification":"payment","approved":false,"observationHash":"sha256:229e8a72c5f0073a48b02dce59d8e6993869b2719e3abf7c210fb20f8bebb186","beforeHash":"sha256:229e8a72c5f0073a48b02dce59d8e6993869b2719e3abf7c210fb20f8bebb186","afterHash":"sha256:229e8a72c5f0073a48b02dce59d8e6993869b2719e3abf7c210fb20f8bebb186","verified":false,"executed":false,"error":"E_REFUSED","prevHash":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","hash":"sha256:fdf497d4eb7df69eedeca5ab1257c77edab1219066c6758935038a6b02515b73"}],"narration":["payment.pay failed: E_REFUSED"]}
[sidecar] headless turn done: records=1 approvals=1 chainOk=true
```

The device was never called: `headless` has no `tap`, and `executed=false` means
the executor stopped at the gate.

## No host attached: are we honest?

```
[sidecar] turn cli-1 in c-d38954eb-…: click the save button
{"type":"turn.end",…,"answer":"I could not do that: no device is attached in headless mode; cannot tap","records":1,"executed":0,"denied":0,"steps":[…,"classification":"read","approved":null,"executed":false,"error":"E_UNSUPPORTED"…]}
```

The action is classified `read`, so no approval was asked; the device refused,
and the turn said so. This is the difference between a stub and a lie.

## Continuation

```
[sidecar] turn cli-1 in c-14c384e6-238d-4ad7-97dc-341fc0fa78b7: say hello again
{"type":"turn.end",…,"title":"say hello","answer":"Stub answered: \"say hello again\".","records":0}
```

The conversation file holds four messages: the first question, its answer, the
second question, its answer. The title stayed "say hello".

## Record persistence

`records.json` holds the failed tap of the headless run:

```
[{"conversationId":"c-d38954eb-…","runId":"run-cli-1","createdAt":1794759309364,
  "records":[{"runId":"run-cli-1","step":0,"action":{"kind":"ui.tap","x":700,"y":600},
  "classification":"read","approved":null,"executed":false,"error":"E_UNSUPPORTED",
  "prevHash":"sha256:e3b0…b855","hash":"sha256:0b66…e849"}]}]
```

The chain seed is the SHA-256 of the empty string, which is the same constant
`RunChain.SEED` uses. `chainOk: true` in every envelope above.

## `task.*` is refused, not ignored

```
host -> {"type":"hello"}
sidecar -> {"type":"ready","version":1}
host -> {"type":"task.list","id":"a"}
sidecar -> {"type":"task.error","id":"a","request":"task.list","ok":false,"code":"E_UNSUPPORTED","error":"task handoff is not implemented on this build; it arrives in P4"}
host -> {"type":"hello"}
sidecar -> {"type":"ready","version":1}
```

## Reproduce

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar test --no-daemon
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon

$java = "$env:JAVA_HOME\bin\java.exe"
$cp   = "..\windows\sidecar\build\install\hopa-windows-sidecar\lib\*"
& $java -cp $cp com.hopa.sidecar.MainKt --turn "say hello" --data-dir .\tmp\p1
& $java -cp $cp com.hopa.sidecar.MainKt --turn "pay 100 for the order" --data-dir .\tmp\p1-deny
```

On a machine without JDK 17, pass the installation path:

```
-Porg.gradle.java.installations.paths=<path-to-jdk-17>
```

## Limits, stated

- Headless deliberately uses the stub model. A real provider needs the window,
  where the key lives in Credential Manager.
- No .NET host is attached, so the PC target is not exercised here. That is P2.
- The approval gateway denies everything; the allow path is the window's
  `HostApproval`, which times out to deny.
