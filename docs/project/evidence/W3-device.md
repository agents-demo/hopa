# W3 — the Windows device adapter

Date: 2026-11-14. Host: Windows; .NET 8; session unlocked for the final matrix.

## What exists

- `apps/windows/Hopa.Windows/Device/WindowsDevice.cs`: a real UI Automation adapter.
  - `Observe` builds the observation JSON for the Kotlin contract: a pre-order
    tree with refs (`e1`..), control type, name, automation id, bounds,
    clickable/scrollable/focused/enabled/visible, and password fields marked as
    `password` so the producer drops them.
  - `tap` tries the UIA patterns first (`Invoke`, `SelectionItem`) and falls back
    to a mouse click at the element centre or the given coordinates.
  - `doubleTap`, `longPress`, `type` (Value pattern, then the keyboard), `swipe`,
    `back` (Escape), `home` (Win+D), `launch` (shell), `foreground` (process).
  - Every property read and pattern call is wrapped: a control that disappears
    throws a readable error instead of crashing the host.
- The sidecar sends `observe` over NDJSON and runs `ObservationProducer` on the
  host's tree, so redaction, caps, refs and the hash stay in one place.
- The W1 notepad-only clicker is gone; the host is a device adapter now.

## Verified so far

`Hopa.Windows.exe --pc-check` (the session was already locked):

```
device: observed 32 nodes in 'LockApp'
device: launched notepad
device: observed 32 nodes in 'LockApp'
step #0 ui.launch [read] executed=True verified=False hash=sha256:0ca
device: observed 32 nodes in 'LockApp'
device: typed 15 chars
device: observed 1 nodes in 'Idle'
step #0 ui.type [read] executed=True verified=True hash=sha256:a64
```

What this proves: the observation is a real UIA tree (32 nodes from the lock
screen), the producer accepts it, refs and the hash are attached, `launch` works,
and `foreground` reports the process name.

What it does **not** prove: that a click or typed text reached a real control.
`verified=True` on the type step is the observation changing from `LockApp` to
`Idle` when the lock screen handed over, not the text landing in Notepad. The
lock screen is a secure surface; the honest answer is "cannot see or touch", not
a success.

## Secure surface (the lock screen)

The session was locked, so the foreground process was `LockApp` — a real secure
surface. The adapter now refuses before touching anything:

```
device error: the screen is 'LockApp' (locked or secure); HOPA cannot see or touch it
HOPA: I could not do that: the screen is 'LockApp' (locked or secure); HOPA cannot see...
step #0 ui.launch [read] executed=False verified=False error=E_DEVICE hash=sha256:ea6
```

Both the observation and the action refuse; no false success, no screenshot. That
closes W0's last box: a secure window says "cannot see or touch" and the app
repeats it.

## Sidecar tests

Six JVM tests cover the files the sidecar owns (ChatStore, PendingApprovals,
RecordStore). They run without a desktop and are wired into the Android CI job:

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar test --no-daemon
```

```
:core:test            (the shared loop and gate fixtures)
:test                 ChatStoreTest 2, PendingApprovalsTest 2, RecordStoreTest 2
BUILD SUCCESSFUL
```

## Live matrix (unlocked session)

`Hopa.Windows.exe --matrix-check out.txt` drives the adapter directly: launch,
wait for the window, force it forward, observe, screenshot, and for Notepad click
the edit field and type.

```
blind type refused: type needs a ref on Windows; blind typing would hit whatever window is focused
--- notepad
launched notepad (foreground=notepad)
observe: app=Notepad nodes=45
screenshot: windows-matrix-notepad.png (38540 bytes)
type via e3: readback='HOPA matrix 2026'
--- calc
launched calc (foreground=applicationframehost)
observe: app=ApplicationFrameHost nodes=54
screenshot: windows-matrix-calc.png (39235 bytes)
--- explorer
launched explorer (foreground=explorer)
observe: app=explorer nodes=331
screenshot: windows-matrix-explorer.png (314332 bytes)
--- chrome
launched chrome (foreground=chrome)
observe: app=chrome nodes=106
screenshot: windows-matrix-chrome.png (81058 bytes)
--- code
launched code (foreground=code)
observe: app=Code nodes=120
screenshot: windows-matrix-code.png (213262 bytes)
```

The five screenshots are `docs/media/windows-matrix-*.png`.

What the matrix proves:

- the observation is a real UIA tree per app (45–331 nodes), with refs and the
  producer's hash;
- **launch brings the app forward** and refuses when it cannot (see below);
- **typing by ref** reaches the control: Notepad's edit read back
  `HOPA matrix 2026`;
- **screenshots** capture the foreground window as PNG;
- Calculator is a packaged app: its window belongs to `ApplicationFrameHost`,
  which is now accepted because the foreground *handle* is compared, not the
  process name.

## Safety fixes found by the matrix

The first run exposed two dangerous shortcuts, both fixed:

1. **Blind typing.** `type` without a ref typed into whatever window had focus
   (it hit the editor hosting this chat; no Enter was pressed). `type` now
   refuses without a ref.
2. **Silent launch failure.** Notepad did not come forward and the matrix typed
   into the old foreground. `launch` now forces the window forward and throws
   "could not bring it forward" if the foreground handle is still something
   else.

## Close-out: observation rules, patterns, timeouts, DPI

Live transcript (`Hopa.Windows.exe --w3-check out/w3-check.txt`, 2026-11-14):

```
blind type: refused: type needs a ref on Windows; blind typing would hit whatever window is focused
launch: launched notepad (foreground=notepad)
observe: app=Notepad nodes=45 density=1.5 truncated=false
hash stable across two observations: True (sha256:f73468a5...573ec5)
tap: clicked 1910,563
type: set e3 to 14 chars
readback: 'HOPA w3 213749'
screenshot: 35821 bytes
launch calc: launched calc (foreground=applicationframehost)
calc observe: app=ApplicationFrameHost nodes=54
calc tap: invoked e5
```

What it proves, line by line:

| Line | Proves |
|---|---|
| `density=1.5` | the process is per-monitor DPI aware; coordinates are physical pixels (150% here) |
| `hash stable ... True` | two observations of the same screen give the same hash, so a verify step can compare them |
| `tap: clicked` | Notepad's document control offers no Invoke/Toggle/SelectionItem, so the mouse fallback ran |
| `calc tap: invoked e5` | where a pattern exists, the pattern is used: no coordinates involved |
| `type: set e3` | text goes through `ValuePattern`, not keystrokes |

### Observation rules (unit-tested)

`apps/windows/Hopa.Windows.Tests` covers the rules that make an observation
reproducible: per-node text cap (200 chars, marked with `...`), 40 text lines,
4000-character budget, a `sha256:` hash over app + screen + lines, and the
password rule (the name never enters the text).

### Failure taxonomy

| Situation | What HOPA says | Where |
|---|---|---|
| Lock screen or logon desktop | "the screen is '<process>' (locked or secure); HOPA cannot see or touch it" | `RefuseSecureSurface` |
| Elevated window, HOPA normal | names the app, says Windows blocks the boundary, links `docs/guides/windows/uiaccess.md` | `RefuseElevatedBoundary` |
| Pattern offered but fails | falls back to the mouse on the same ref, reports the click | `TryPattern` |
| UIA provider does not answer | `TimeoutException` after 1500 ms (properties 700 ms), no freeze | `Call` |
| Stale or missing ref | "stale ref e7; observe again" | `PointFor` |
| Type without a ref | "type needs a ref on Windows; blind typing would hit whatever window is focused" | `Type` |
| Launch, no window in 8 s | "launched <app>, but no window appeared" | `Launch` |
| Packaged app | foreground process reads `ApplicationFrameHost`; the handle is what matters | `FindWindowFor` |

## Remaining live checks

- Password-field redaction: the rule is unit-tested; no real password field was
  exercised end to end.
- Elevated windows: the refusal is implemented and documented; the signed
  `uiAccess` helper is blocked on the certificate and not shipped.
- Per-monitor DPI: proven on the primary monitor at 150%; moving the window to a
  second monitor with a different scale is still manual.
- A hung UIA provider is handled in code but was not fault-injected in a live run.
