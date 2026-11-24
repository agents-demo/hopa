# Windows desktop CI (real UI Automation)

The normal Windows job builds and tests the client, but GitHub-hosted runners
run in session 0: they have no interactive desktop, so they cannot see or drive
a UI. The `Windows desktop (UIA)` workflow therefore targets a **self-hosted**
Windows machine with a logged-in, unlocked session.

## What the workflow proves

`tools/scripts/windows-desktop-checks.ps1` runs the developer checks against the
real desktop and fails on a transcript that says `FAIL` or `error:`:

- `--w3-check`: two observations have the same hash, blind typing is refused,
  and the pattern path works;
- `--p2-check`: the full `DevicePort` contract, including a stale ref, a real
  readback, a screenshot and the Start-menu app list;
- `--matrix-check`: Notepad, Calculator, Explorer, Chrome and VS Code are
  launched and observed (missing apps are reported, not invented);
- `--w4-check`: the tray, high contrast, placement and automation names;
- `--keyboard-check`: the focusable stops in visual-tree order;
- `--shot-chat`, `--shot-components`, `--shot-frame`, `--shot-settings`: the W6
  screenshots.

The transcripts and PNGs are uploaded as `hopa-windows-desktop`.

## Runner requirements

Use a dedicated Windows 11 machine or VM. A UIA run drives the mouse, keyboard
and foreground window, so do not use a personal desktop.

1. Create a dedicated local user with **auto-login** (or keep one interactive
   session signed in).
2. Install the .NET 8 SDK, JDK 17, and the GitHub Actions runner.
3. Start the runner **from the interactive session** (`run.cmd` from a normal
   shell, or a startup shortcut). Do **not** install it as a Windows service:
   a service runs in session 0 and every UI check will fail honestly.
4. Register it with the labels `self-hosted`, `windows`, `x64`,
   `hopa-desktop`.
5. Disable the lock screen, screensaver, sleep and display timeout for that
   user. A disconnected RDP session can leave the desktop locked; prefer a
   local console or a VM console that stays connected.
6. Install Chrome and VS Code if the app matrix should cover them. The matrix
   records a missing app instead of pretending it was observed.
7. Keep a clean desktop: no Notepad or Calculator already open. The P2 check
   skips its readback rather than touching an existing Notepad document, and a
   clean runner is what the assertions expect.

## Enabling it

The job is skipped for pushes and the weekly schedule unless the repository
variable `ENABLE_WINDOWS_DESKTOP` is `true`. A manual **Run workflow** always
runs. This avoids queueing work for a machine that does not exist yet.

Do not add `pull_request` to this workflow. A self-hosted runner executes the
repository's code; a fork PR must never reach that machine.

## Running it locally

On an unlocked interactive desktop with the sidecar installed:

```powershell
cd C:\work\hopa
.\tools\scripts\windows-desktop-checks.ps1 -ReadyOnly
.\tools\scripts\windows-desktop-checks.ps1 -Output out\windows-desktop
```

`-ReadyOnly` checks the session, Explorer, the lock state and the foreground
window without touching any app. Add `-SkipBuild` when the DevTools build is
already current.

The two refusals that need a human (locking the screen and approving a UAC
prompt) remain manual; see [p2-testing.md](p2-testing.md).
