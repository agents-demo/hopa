# HOPA for Windows

Status: **W0 spike**, the engine seam works; the shell is next
([plan](../../docs/project/plan/windows/README.md), [ADR-0021](../../docs/design/decisions/0021-windows-client-stack.md)).

```
Hopa.Windows/   WPF app: window, sidecar client, one UIA action (FlaUI)
sidecar/        Kotlin host for packages/core + packages/capabilities (NDJSON over stdio)
```

This folder used to describe a *thin* client that would not run the loop. That
was superseded: clients own the loop (ADR-0016), so the loop runs here in the
Kotlin sidecar and the C# app is the host around it (ADR-0021).

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

Type a goal and press Send. The spike goals:

- `say hello` - one turn through the loop and back;
- `click the notepad text area` - the engine asks the host for a UI Automation
  click and the host performs it.

Headless verification:

```powershell
.\bin\Debug\net8.0-windows\Hopa.Windows.exe --turn "say hello" --out result.txt --shot shot.png
```

## Rules

1. The loop, the gate and the records live in `packages/`, inside the sidecar.
   The C# app never decides whether an action is allowed.
2. The adapter reports **what it can see**. UI Automation trees are sparse, so
   `observe` must say when it only has window titles.
3. Payment and destructive actions go through the same ask-first gate; the
   adapter only reports.
4. Sealing is one-way: nothing here may be imported by `services/` or `evals/`.
5. Keys stay in Windows Credential Manager; the sidecar receives them in memory
   only (W2).

The protocol is in [`docs/project/plan/windows/protocol.md`](../../docs/project/plan/windows/protocol.md);
the W0 evidence is in [`docs/project/evidence/W0-spike.md`](../../docs/project/evidence/W0-spike.md).
