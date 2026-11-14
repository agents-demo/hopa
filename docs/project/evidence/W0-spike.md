# W0 — decision and spike

Date: 2026-11-14. Host: Windows, .NET SDK 10 (target `net8.0-windows`), JDK 17.

The spike proves the seam before any UI work: a .NET window runs a turn in the
Kotlin engine and the engine asks the host to perform one UI Automation action.

## What exists

```
apps/windows/
  Hopa.Windows/           WPF app (C#): window, SidecarClient, NotepadClicker
  sidecar/                Kotlin host for packages/core + packages/capabilities
docs/design/decisions/0021-windows-client-stack.md
docs/project/plan/windows/protocol.md
```

The sidecar is a Gradle build of its own; it includes `packages/core` and
`packages/capabilities` by path and ships as an `installDist` directory.

## Build

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon

cd ..\windows\Hopa.Windows
dotnet build -c Debug
```

Both are green (`installDist` in 29 s, `dotnet build` with 0 warnings).

## Protocol check without .NET

The sidecar was driven from PowerShell with redirected stdio:

```
READY: {"type":"ready","version":1}
TURN:  {"type":"turn.end","id":"t1","answer":"Sidecar answered: \"say hello\"."}
```

And with a device round-trip (the harness answered `device.result` by hand):

```
REQUEST: {"type":"device.request","id":"req-1","op":"tap","x":700,"y":600}
TURN:    {"type":"turn.end","id":"t2","answer":"Sidecar answered: \"click the notepad text area\"."}
```

That is the real `AgentLoop` and the real `ActionExecutor` in the sidecar; only
the model is scripted (`SpikeModel`).

## One turn from the window

```
Hopa.Windows.exe --turn "say hello" --out w0-turn.txt --shot docs/media/windows-w0.png
```

```
you: say hello
sidecar: [sidecar] ready (protocol v1)
sidecar: [sidecar] turn g-86df695a29d04911a7bfceae426c5fe8: say hello
HOPA: Sidecar answered: "say hello".
```

The window with that log: `docs/media/windows-w0.png`.

## One UIA click

```
Hopa.Windows.exe --turn "click the notepad text area" --out w0-click.txt
```

```
you: click the notepad text area
sidecar: [sidecar] ready (protocol v1)
device: clicked Notepad 'opencode.jsonc - Notepad' text area at 640,464
HOPA: Sidecar answered: "click the notepad text area".
```

The host received `device.request` with `op: tap`, found the Notepad window with
UI Automation, took the text area's bounds, clicked its centre with FlaUI, and
answered `device.result`. Notepad was already open on this machine with a file;
the click moved the caret and changed nothing else.

## Not done yet

- **Secure surface refusal.** The W0 box asks for a UAC/elevated window that
  returns "cannot see or touch". That guard belongs with the `WindowsDevice`
  adapter in W3; the spike can only show the refusal path for an unsupported op.
  The box stays unticked.
- **The coordinates are a hint.** The sidecar sends `x`/`y` from the scripted
  decision, but the host clicks the Notepad text area it finds, so the spike
  proves the message, not the coordinate contract. W3 makes coordinates real.
- **No real model, no approvals UI, no persistence.** Those are W1 and W2.
- **No MSI.** Packaging is W5; ADR-0021 lists it as spike acceptance, but the
  plan schedules it later on purpose so the seam is proven first.
- The first `AttachOrLaunch` attempt failed with "Could not find process with
  id: 8700" because Windows 11 Notepad redirects to the packaged app; the host
  now finds the window by name/process on the desktop. This is recorded because
  the same class of problem will return for Store apps in W3.

## Verdict

The seam works: window -> `turn.start` -> real loop -> `device.request` ->
FlaUI click -> `device.result` -> `turn.end`. Proceed to W1 (shell) once the
secure-surface box is settled as W3 work.
