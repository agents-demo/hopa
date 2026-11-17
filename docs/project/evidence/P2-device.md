# P2 — the PC target

Date: 2026-11-16. Host: Windows 11 (10.0.22631), .NET 8.0.428, JDK 17.
Adapter: `apps/windows/Hopa.Windows/WindowsDevice.cs`.
Guide: [`docs/guides/windows/p2-testing.md`](../../guides/windows/p2-testing.md).

## What P2 added

| Thing | Where |
|---|---|
| `stop` — ask an app's window to close, report a save prompt, never kill it | `WindowsDevice.Stop` |
| `apps` — the Start menu as `{package, label}`, cached for a minute | `WindowsDevice.Apps` |
| `screenshot` — a base64 PNG or no frame for a protected surface | `WindowsDevice.CaptureWindow` + `HostDevice.screenshot` |
| no-tree refusal — one anonymous node is "cannot see its controls", not an empty screen | `ObservationRules.IsTreeOnlyRoot` |
| the sidecar speaks all three ops | `HostDevice.stop/screenshot/apps` |
| the host reports which path ran | `device.result.text`, logged by `MainWindow` |
| launch survives a terminal parent | `ForceForeground` releases the foreground lock with a bare ALT press when Windows refuses the first `SetForegroundWindow` |
| one-command check | `Hopa.Windows.exe --p2-check <out.txt>` |
| the two human refusals | `--p2-wait <out.txt> [seconds]` |

Unit tests: `ObservationRulesTests` grew from 8 to 11 (empty tree, title-only
window, real tree). The C# suite passes 11/11.

## Live transcript (this machine)

```
adapter: full DevicePort contract
type without ref: refused: type needs a ref on Windows; blind typing would hit whatever window is focused
stale ref: refused: stale ref e9999; observe again
apps: 84 from the Start menu
  Access -> C:\Program Files\Microsoft Office\root\Office16\MSACCESS.EXE
  Administrative Tools -> C:\Windows\system32\control.exe
  Adobe Acrobat -> C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe
  Android Studio -> C:\Program Files\Android\Android Studio1\bin\studio64.exe
  BitLockerConfig -> C:\Program Files (x86)\SPES5.0\Composites\BitLockerConfig\BitLockerConfig.exe
screenshot: 139297 bytes
stop a missing app: refused: 'hopa-no-such-app' is not running
launch notepad: launched C:\Users\...\hopa-p2-123738.txt (foreground=notepad)
observe: app=Notepad nodes=68 density=1 truncated=true
hash stable: True (sha256:060371ec29c)
stop notepad: stopped notepad
foreground after stop: OpenCode
launch notepad again: launched C:\Users\...\hopa-p2-123738.txt (foreground=notepad)
observe again: app=Notepad nodes=68
tap: clicked 640,398
type: set e3 to 14 chars
readback: 'HOPA p2 123750'
readback matches: True
launch calc: launched calc (foreground=applicationframehost)
calc observe: app=ApplicationFrameHost nodes=57
calc tap: invoked e5
no-tree rule: ObservationRules.IsTreeOnlyRoot (unit test)
lock/elevated: manual, see docs/guides/windows/p2-testing.md
```

What this run proves:

- a blind type is refused **before** any window is touched;
- a stale ref is refused with "observe again";
- the app list is real (84 Start-menu shortcuts with existing executables);
- a screenshot is a real frame (139,297 bytes);
- stopping an app that is not running is a readable refusal;
- Notepad is launched, observed, closed, relaunched, tapped, typed into and
  **read back** (`readback matches: True`);
- the observation hash is stable across two reads of the same screen;
- Calculator is driven through the **pattern** path (`invoked e5`), not
  coordinates.

## The foreground fix

The first runs (from a terminal) failed with
`could not bring it forward (foreground=opencode)`: Windows blocks a background
process from stealing focus. `ForceForeground` now:

1. calls `SetForegroundWindow`;
2. if that is refused, sends a bare **ALT down/up** — nothing else — which
   releases the foreground lock;
3. tries `SetForegroundWindow` again;
4. falls back to attaching to the foreground thread;
5. still verifies the handle afterwards, and fails honestly if none of it worked.

The ALT press never types into the target and never reaches a document. The
sequence above is why the same command now reports `foreground=notepad`.

## Safety in the check

- It launches Notepad with **one fixed scratch file** (`%TEMP%\hopa-p2-scratch.txt`)
  and leaves it in place: Windows 11 Notepad restores tabs, and a deleted path
  would pop a "Cannot find the file" dialog on the next launch.
- If a Notepad window is already open, it **skips** the read-back instead of
  adding a tab to the person's session. Close Notepad and rerun for the full check.
- It records the process IDs that existed before it started and closes only the
  ones it created. A pre-existing Notepad or Calculator is never touched.
- A failed step does not abort the run; the transcript always reaches disk.
- The only `Kill` is the check's own scratch instance.

## Lock-screen and elevated-window refusals (captured 2026-11-17)

Step 6 of the guide, on a real desktop session. The watcher stops on the first
matching refusal, so there is no timer to race.

`--p2-wait <out>\lock.txt 60` — pressed Win+L while it polled:

```
watching for a refusal for up to 60s — lock the screen whenever you are ready
refused: the screen is 'LockApp' (locked or secure); HOPA cannot see or touch it
```

`--p2-wait <out>\uac.txt 60 elevated` — `Start-Process notepad -Verb RunAs`,
approved the prompt and left the elevated window in front:

```
watching for an elevated window for up to 60s — approve the UAC prompt and leave the app in front
secure desktop seen (the consent dialog); still waiting for the elevated window
refused: 'Notepad' runs elevated and HOPA does not; Windows blocks input across that boundary. Install the signed uiAccess helper (docs/guides/windows/uiaccess.md) or run HOPA elevated on purpose.
```

The two sentences are distinct, so the plan's "honest failure" assertion holds:
the lock screen is a secure-surface refusal, the elevated app is a boundary
refusal. The elevated capture first timed out with `no elevated window within
60s (foreground=OpenCode)` — the watcher checks the *foreground* window, so the
elevated Notepad had to be clicked forward after the prompt was approved. The
retry above is the valid one. This closes the last P2 checkbox.
