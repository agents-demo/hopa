# HOPA for Windows

Status: **P1–P4 code complete; the P4 hardware gate is pending.** The
shared engine runs headless through the real gate, the PC adapter implements the
whole `DevicePort` contract, a settings launch becomes a URI before any
click, and a PC action can ask the paired phone for approval. The desktop leg of
the Android program
([plan](../../docs/project/plan/windows/README.md),
[protocol](../../docs/project/plan/windows/protocol.md),
[parity](../../docs/project/plan/windows/parity.md), [ADR-0021](../../docs/design/decisions/0021-windows-client-stack.md)).

```
Hopa.Windows/               WPF app: Ui (shell, panes, chat, dialogs), Themes,
                            Integrations (engine, gateway, voice, device), Host,
                            Storage, Cli (--turn, --list)
Hopa.Windows.Checks/        windowless developer gates (device, intent, voice)
Hopa.Windows.DevTools/      dev WPF exe: every --…-check, W4/W6 and screenshots
Hopa.Windows.Tests/         unit tests
Hopa.Windows.IntegrationTests/  a real engine process and a loopback WebSocket
Hopa.Windows.FakeEngine/    the tiny NDJSON host those integration tests start
sidecar/                    Kotlin engine host for packages/ (NDJSON over stdio)
installer/                  WiX MSI
```

Inside `Hopa.Windows/`:

| Folder | What the reader finds |
|---|---|
| `Ui/Shell/` | the main window, its parts, the tray, placement and the automation harness |
| `Ui/Panes/` | the window's panes and their view models: rail, sidebar, chat |
| `Ui/Chat/` | the rows and the mark a conversation is drawn from |
| `Ui/Dialogs/` | approval, settings, rename, run details |
| `Themes/` | the shared product styles, merged by the app and by DevTools |
| `Integrations/Engine/` | the Kotlin engine host: client, transport, `IChatEngine`, process, turn result |
| `Integrations/Gateway/` | the phone/backend link: credentials, pairing, socket |
| `Integrations/Voice/` | microphone, bridge speech, WAV |
| `Integrations/Device/` | this PC as a device: UI tree, input, desktop, apps, observation rules |
| `Host/` | app coordination: `EngineSession`, `ChatController`, `ApprovalRouter`, `DeviceRequestRouter`, reports |
| `Storage/` | settings and Windows Credential Manager |
| `Cli/` | the two product modes: `--turn` and `--list` |

`Hopa.Windows.Checks` has no window; `Hopa.Windows.DevTools` owns the developer
flags, the W4/W6 checks and the screenshots, so the shipped exe does not carry
them.

The C# app is the host; the loop, the gate and the records run in the Kotlin
sidecar from `packages/` (ADR-0016, ADR-0021). There is no second brain. The
sidecar folder has its own [README](sidecar/README.md) with its layout and
message families.

## Build

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon

cd ..\windows\Hopa.Windows
dotnet build -c Debug
```

The developer tools build against the product:

```powershell
dotnet build apps\windows\Hopa.Windows.DevTools -c Debug
```

The app finds the sidecar at `sidecar/build/install/hopa-windows-sidecar/lib`;
set `HOPA_SIDECAR_LIB` to override.

## Run

```powershell
.\bin\Debug\net8.0-windows\Hopa.Windows.exe
```

## Headless: the P1 gate

The sidecar runs one turn without a window. No host is attached, so there is no
screen and no device; actions fail honestly instead of pretending. Approvals
deny by default.

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon

java -cp "..\windows\sidecar\build\install\hopa-windows-sidecar\lib\*" `
  com.hopa.sidecar.MainKt --turn "say hello" --data-dir .\tmp\p1
```

The envelope is printed on stdout and logs go to stderr. `--conversation <id>`
continues a thread. Headless always uses the scripted proposer: no model key is
loaded, and no host is attached, so there is nothing to allow an action.

The deny path:

```powershell
java -cp "..\windows\sidecar\build\install\hopa-windows-sidecar\lib\*" `
  com.hopa.sidecar.MainKt --turn "pay 100 for the order" --data-dir .\tmp\p1-deny
```

The envelope reports `executed=0`, `denied=1`, and the step carries
`approved=false`, `executed=false`, `error=E_REFUSED`. The device is never
called.

## Test the PC target (P2)

The full first-run guide is
[`docs/guides/windows/p2-testing.md`](../../docs/guides/windows/p2-testing.md).
The self-hosted desktop run is
[`docs/guides/windows/desktop-ci.md`](../../docs/guides/windows/desktop-ci.md).
The short version, after building the sidecar:

```powershell
cd apps\windows\Hopa.Windows.DevTools
New-Item -ItemType Directory -Force -Path "$env:TEMP\hopa-p2" | Out-Null
dotnet run -c Debug -- --p2-check "$env:TEMP\hopa-p2\p2-check.txt"
```

That opens Notepad with a scratch file, observes, stops it, relaunches, types
and reads back, refuses a stale ref, captures a frame, lists the Start-menu apps,
and drives Calculator through the UIA pattern path. Two refusals need a human:

```powershell
dotnet run -c Debug -- --p2-wait "$env:TEMP\hopa-p2\lock.txt" 60            # press Win+L
dotnet run -c Debug -- --p2-wait "$env:TEMP\hopa-p2\uac.txt" 60 elevated    # approve the UAC prompt
```

## Test the path selector (P3)

```powershell
dotnet run -c Debug -- --p3-check "$env:TEMP\hopa-p3\check.txt"
cd ..\Hopa.Windows
dotnet run -c Debug -- --turn "open wifi settings" --out "$env:TEMP\hopa-p3\turn.txt"
```

The first refuses `file:` and `shell:` and opens `ms-settings:network-wifi`; the
second must log `step 0: system.openLink tier=intent` and verify against the
Settings window. `--turn` starts the sidecar, so `JAVA_HOME` must be set.

## Pair the phone (P4)

Open **Settings → Phone link**, paste the `hopa://pair?...` link the backend
printed for this PC, and press **Pair this PC**. The PC claims its own credential
with `platform=windows`; the token pair is stored in Windows Credential Manager.
When the phone is online, an approval for a PC action is sent to it, and the
answer is written to the run record as `approver.device = "phone"`. A dead link
or a late answer denies, never allows.

The gateway flow is in `GatewayClient.cs`; the phone side is
`RemoteApprovalRunner.kt`. The implementation record is
[`docs/project/evidence/P4-phonelink.md`](../../docs/project/evidence/P4-phonelink.md).

## Run the tests

```powershell
dotnet test apps\windows\Hopa.Windows.Tests -c Debug
dotnet test apps\windows\Hopa.Windows.IntegrationTests -c Debug
```

The unit suite covers rules, rows, view models, approvals, settings, the CLI,
the gateway frame contract, the NDJSON transport and the device ports through
fakes. The integration suite starts a real engine child process and a loopback
WebSocket server; it needs no interactive desktop.

## Package

The product zip and MSI contain only `Hopa.Windows`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\scripts\windows-package.ps1 -SkipMsi
```

`tools/scripts/windows-package.ps1` publishes the product, builds the jlink
runtime, and refuses to continue if any DevTools, Checks, FakeEngine or test
assembly leaked into the stage. The MSI consumes the same product-only stage.

The developer tools are a separate build (and a separate CI artifact):

```powershell
dotnet publish apps\windows\Hopa.Windows.DevTools -c Debug -o out\windows-devtools
```

## Rules

1. The loop, the gate and the records live in `packages/`, inside the sidecar.
   The C# app never decides whether an action is allowed.
2. The adapter reports **what it can see**. UI Automation trees are sparse, so
   `observe` must say when it only has window titles.
3. Payment and destructive actions go through the same ask-first gate; the
   adapter only reports.
4. A stub may be dumb, never permissive: the headless approval gateway denies,
   the scripted model only proposes, and a missing host means "cannot act", not
   "done".
5. Keys stay in Windows Credential Manager; the sidecar receives them in memory
   only.
6. Sealing is one-way: nothing here may be imported by `services/` or `evals/`.
