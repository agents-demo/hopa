# Testing P2 on a fresh Windows machine

This guide assumes **nothing is installed**. It takes a clean Windows 10/11 x64
machine to a working HOPA desktop client and runs the P2 checks. P2 covers the
PC target only: no phone and no model key are needed.

Time: 20–30 minutes, most of it downloads.

## What you need

| Thing | Why | Required |
|---|---|---|
| Windows 10 or 11, x64 | the client is WPF + UI Automation | yes |
| Git | get the code | yes |
| JDK 17 | build and run the Kotlin sidecar | yes |
| .NET 8 SDK | build the WPF app | yes |
| ~2 GB free disk | Gradle, NuGet, JDK, .NET | yes |
| Admin rights | only for the optional UAC test | no |

A phone is **not** part of P2. A model key is **not** part of the automatic check.

## Step 1 — Install the tools

Open **PowerShell** (normal user is enough).

```powershell
winget install --id Git.Git -e
winget install --id EclipseAdoptium.Temurin.17.JDK -e
winget install --id Microsoft.DotNet.SDK.8 -e
```

If `winget` is unavailable, install from these pages instead:

- Git: <https://git-scm.com/download/win>
- JDK 17 (Temurin): <https://adoptium.net/temurin/releases/?version=17>
- .NET 8 SDK: <https://dotnet.microsoft.com/download/dotnet/8.0>

**Close and reopen PowerShell** so the new `PATH` is picked up, then verify:

```powershell
git --version
java -version        # must say 17.x
dotnet --version     # must say 8.x
```

If `java -version` shows a different major version, set `JAVA_HOME` for this
session to the JDK 17 folder:

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17...\"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

## Step 2 — Get the code

```powershell
cd C:\
mkdir work
cd C:\work
git clone https://github.com/Nizzanki/hopa.git
cd hopa
```

If you already have a checkout, `git pull` and continue from there.

## Step 3 — Build the sidecar (the engine)

The WPF app is only a host; the agent loop lives in the Kotlin sidecar.

```powershell
cd apps\android
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon
```

The first run downloads Gradle and dependencies — expect 5–10 minutes.

Success looks like:

```
BUILD SUCCESSFUL
```

and this folder exists:

```
apps\windows\sidecar\build\install\hopa-windows-sidecar\lib
```

If Gradle says no Java 17 toolchain was found, point it at one explicitly:

```powershell
.\gradlew.bat -p ..\windows\sidecar installDist --no-daemon `
  "-Porg.gradle.java.installations.paths=C:\Program Files\Eclipse Adoptium\jdk-17..."
```

## Step 4 — Run the automated tests

```powershell
cd C:\work\hopa\apps\android
.\gradlew.bat -p ..\windows\sidecar test --no-daemon
```

Expected: **25 tests, 0 failures** (six suites, including the P1 gate).

Then the C# tests:

```powershell
cd ..\windows\Hopa.Windows
dotnet test ..\Hopa.Windows.Tests -c Debug
```

Expected: **11 tests, 0 failures** (observation caps, hash, password rule,
empty-tree rule).

## Step 5 — Run the automatic P2 check

This is the main check. It opens Notepad and Calculator, so keep the desktop
free for about 30 seconds.

```powershell
cd C:\work\hopa\apps\windows\Hopa.Windows
New-Item -ItemType Directory -Force -Path "$env:TEMP\hopa-p2" | Out-Null
dotnet run -c Debug -- --p2-check "$env:TEMP\hopa-p2\p2-check.txt"
```

It launches Notepad, observes twice, stops it, launches it again, types into the
document and reads it back, tries a stale reference, takes a screenshot, lists
the Start menu apps, exercises Calculator, and tries to stop an app that is not
running. Nothing is simulated and nothing is killed silently.

Two safety details: it opens a **scratch file** in Notepad so Windows 11's tab
restore cannot type into a real document, and it records which processes already
existed so it closes only the ones it started. The scratch file has one fixed
name and is left in `%TEMP%`, so tab restore never points at a deleted file. If a
Notepad window is already open, the check **skips** the Notepad part instead of
adding a tab to your session.

Close Notepad before running if you want the typed read-back.

Read the transcript:

```powershell
Get-Content "$env:TEMP\hopa-p2\p2-check.txt"
```

### What success looks like

```
adapter: full DevicePort contract
type without ref: refused: type needs a ref on Windows; blind typing would hit whatever window is focused
launch notepad: launched notepad (foreground=notepad)
observe: app=Notepad nodes=45 density=1.5 truncated=false
hash stable: True (sha256:f73468a5...)
stop notepad: stopped notepad
foreground after stop: explorer
launch notepad again: launched notepad (foreground=notepad)
tap: clicked 1910,563
type: set e3 to 14 chars
readback: 'HOPA p2 101500'
readback matches: True
stale ref: refused: stale ref e9999; observe again
screenshot: 35821 bytes
apps: 87 from the Start menu
  Calculator -> C:\Windows\System32\calc.exe
  Notepad -> C:\Windows\System32\notepad.exe
  ...
launch calc: launched calc (foreground=applicationframehost)
calc observe: app=ApplicationFrameHost nodes=54
calc tap: invoked e5
stop a missing app: refused: 'hopa-no-such-app' is not running
no-tree rule: ObservationRules.IsTreeOnlyRoot (unit test)
lock/elevated: manual, see docs/guides/windows/p2-testing.md
```

Numbers (nodes, app count, bytes, coordinates) will differ on your machine.
The lines that must hold are:

| Line | Must show |
|---|---|
| `type without ref` | `refused:` — never `FAIL` |
| `launch notepad` | `launched notepad` |
| `hash stable` | `True` |
| `stop notepad` | `stopped notepad` |
| `readback` | the same text you see in `type` |
| `readback matches` | `True` |
| `stale ref` | `refused: stale ref ... observe again` |
| `screenshot` | a byte count, or `none` on a protected window |
| `apps` | a number greater than 0 |
| `calc tap` | `invoked ...` (the pattern path, not a click) |
| `stop a missing app` | `refused: ... is not running` |

If any line says `FAIL (it was allowed)`, stop: a refusal became permissive.

## Step 6 — The two refusals that need a human

The adapter cannot trigger a lock screen or an elevation prompt by itself. This
command watches the foreground and stops on the **first refusal**, so there is no
timer to race.

### 6.1 Lock screen

```powershell
dotnet run -c Debug -- --p2-wait "$env:TEMP\hopa-p2\lock.txt" 60
```

Press **Win+L** whenever you are ready within the minute. The waiter stops as
soon as it sees the secure desktop. Stay locked for a few seconds, sign back in,
then read:

```powershell
Get-Content "$env:TEMP\hopa-p2\lock.txt"
```

If it says `no refusal within 60s (foreground=...)`, the machine was still
unlocked at every poll: rerun and lock sooner.

Expected, in one of two honest forms — Windows exposes either the lock app or
only a secure desktop with no readable process:

```
refused: the screen is 'LockApp' (locked or secure); HOPA cannot see or touch it
```

```
refused: the screen is locked or secure; HOPA cannot see or touch it
```

Both are the lock refusal. `'Idle' exposes no UI Automation tree` is **not**
correct anymore: a zero or unnamable foreground process is the secure desktop,
and the adapter now says so.

### 6.2 Elevated window

The elevation check is about a **window that runs elevated**, not the consent
dialog: the consent dialog is on the secure desktop, and Windows hides it from a
normal process (it looks the same as the lock screen). Approve the prompt, then
leave the elevated app in front.

Start the waiter in `elevated` mode. It ignores the consent dialog's secure
desktop (which looks like the lock screen) and stops only when an approved,
elevated window is in front:

```powershell
cd C:\work\hopa\apps\windows\Hopa.Windows
dotnet run -c Debug -- --p2-wait "$env:TEMP\hopa-p2\uac.txt" 60 elevated
```

Then open an elevated app and approve the prompt:

```powershell
Start-Process notepad -Verb RunAs
```

Click **Yes** on the UAC dialog and leave the elevated Notepad in front. Then
read:

```powershell
Get-Content "$env:TEMP\hopa-p2\uac.txt"
```

Expected:

```
secure desktop seen (the consent dialog); still waiting for the elevated window
refused: 'Notepad' runs elevated and HOPA does not; Windows blocks input across
that boundary. Install the signed uiAccess helper ... or run HOPA elevated on purpose.
```

The first line is expected: the consent dialog itself lives on the secure
desktop, so the watcher notes it and keeps polling until the approved window is
in front.

## Step 7 — One manual turn in the window (optional, no key)

The check above calls the adapter directly. To see the whole loop:

```powershell
dotnet run -c Debug
```

In the window, type **`open notepad`** and press **Ctrl+Enter**. With no model
key, the sidecar uses its deterministic stub, which proposes launching Notepad.
You should see the step in the rail and Notepad in front.

Then try **`pay 100 for the order`**. Expect a refusal: the approval sheet asks,
and if you choose **Deny**, the run records `approved=false` / `executed=false`
and nothing is paid. A payment is never remembered.

To use a real model, open **Settings**, choose the provider, endpoint, model and
key, save, and ask a real goal such as *"open Notepad and type hello"*.

## Step 8 — What to keep as evidence

Put these in the pull request or the phase record:

- `$env:TEMP\hopa-p2\p2-check.txt`
- `$env:TEMP\hopa-p2\lock.txt`
- `$env:TEMP\hopa-p2\uac.txt`
- a screenshot of the rail after the manual turn

That is the P2 gate: one benign action, a typed read-back, and three distinct
refusals (lock, elevation, stale/absent reference).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `sidecar library not found at ...` | step 3 not run, or a different output folder | run `installDist`; set `HOPA_SIDECAR_LIB` to the `lib` folder |
| `java did not start` | no JRE on `PATH` and no bundled runtime | install JDK 17 and set `JAVA_HOME` |
| `the screen is 'LockApp'` | session locked | sign in, or use `--p2-wait` deliberately |
| `type needs a ref` | blind typing | expected; observe first and pass a `ref` |
| `stale ref e...` | the screen changed since that observation | observe again; refs live for one observation |
| `notepad: skipped — a Notepad window is already open` | Windows 11 Notepad is tabbed and restores sessions; the check will not type into yours | close Notepad, rerun for the read-back |
| `Could not find ...hopa-p2...txt` in Notepad | an older run's scratch file was deleted before tab restore | close that tab once; the current check keeps one valid scratch file |
| `launched X, but no window appeared within 12 s` | a cold packaged app, or a dialog is blocking it | close dialogs and retry; the adapter already launches once more before failing |
| `launched X, but could not bring it forward` | Windows refused the foreground unlock too (for example a secure desktop or a full-screen app) | close the full-screen app and retry. The adapter already tries a bare ALT unlock and thread attachment before refusing |
| `UI Automation did not answer ...` | a hung provider | retry; the timeout is the protection |
| `dotnet` not found | SDK missing or PATH stale | reopen PowerShell, `dotnet --version` |
| Gradle toolchain error | only JDK 21 installed | install JDK 17 or pass the installations path |
| Screenshot says `none` | protected window (DRM, secure desktop) | expected; it is not a failure |

## Where things live

- Sidecar data (conversations, records, attachments):
  `%USERPROFILE%\.hopa\windows` — override with `HOPA_DATA_DIR`.
- App build: `apps\windows\Hopa.Windows\bin\Debug\net8.0-windows`.
- Sidecar build: `apps\windows\sidecar\build\install\hopa-windows-sidecar`.
- Transcripts: wherever you point them (`$env:TEMP\hopa-p2` in these examples).

## What P2 does not test

- The phone target: that is P4.
- Intent-first routing: that is P3.
- The signed `uiAccess` helper: blocked on a code-signing certificate.
- Vision frames: the Windows host does not enable them yet.
