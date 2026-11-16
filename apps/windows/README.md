# HOPA for Windows

Status: **P1 complete; P2 code complete, one manual gate open.** The shared
engine runs headless through the real gate, and the PC adapter implements the
whole `DevicePort` contract: observe, act, type, launch, stop, screenshot, apps.
The desktop leg of the Android program
([plan](../../docs/project/plan/windows/README.md),
[protocol](../../docs/project/plan/windows/protocol.md),
[parity](../../docs/project/plan/windows/parity.md), [ADR-0021](../../docs/design/decisions/0021-windows-client-stack.md)).

```
Hopa.Windows/   WPF app: window, sidecar client, WindowsDevice (FlaUI/UIA)
sidecar/        Kotlin engine host for packages/ (NDJSON over stdio)
installer/      WiX MSI
```

The C# app is the host; the loop, the gate and the records run in the Kotlin
sidecar from `packages/` (ADR-0016, ADR-0021). There is no second brain.

## Build

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon

cd ..\windows\Hopa.Windows
dotnet build -c Debug
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
The short version, after building the sidecar:

```powershell
cd apps\windows\Hopa.Windows
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

## Rules

1. The loop, the gate and the records live in `packages/`, inside the sidecar.
   The C# app never decides whether an action is allowed.
2. The adapter reports **what it can see**. UI Automation trees are sparse, so
   `observe` must say when it only has window titles.
3. Payment and destructive actions go through the same ask-first gate; the
   adapter only reports.
4. A stub may be dumb, never permissive: the headless approval gateway denies,
   the stub model only proposes, and a missing host means "cannot act", not
   "done".
5. Keys stay in Windows Credential Manager; the sidecar receives them in memory
   only.
6. Sealing is one-way: nothing here may be imported by `services/` or `evals/`.
