# ADR-0021 — Windows client: .NET shell over the Kotlin engine

- Status: accepted
- Date: 2026-11-14
- Owners: Windows lead (TBD)

## Context

Android is the active client and Windows is next (ADR-0020). The client engine
(loop, gate, records, contracts) now lives in `packages/` as pure JVM code so a
second Kotlin client can reuse it without importing `apps/android`.

Two constraints shape the choice:

1. The loop and the payment gate must stay in one place (ADR-0016, ADR-0018).
   A second implementation would be a second brain to audit.
2. The team's strongest desktop skill is .NET, and the riskiest part of a
   Windows client is Windows device control (UI Automation, `SendInput`,
   screenshots, elevated windows), which is native .NET territory.

## Decision

- **UI: .NET 8 + WPF** for the first release. WinUI 3 is the alternative if a
  Fluent look and MSIX become requirements; it is not chosen for v0.
- **The agent loop runs in the existing Kotlin engine** as a local **sidecar**
  (a Gradle module at `apps/windows/sidecar`, shipped as a `jlink` runtime plus
  a fat jar, started as a child process by the app).
- **IPC: newline-delimited JSON over stdio** for v0 (no ports, no firewall
  prompts). A named pipe can replace the transport later without changing the
  message shapes.
- **Device control has two targets:**
  - *phone* — the sidecar uses the existing bridge `AdbDevice` directly;
  - *PC* — a `WindowsDevice` adapter in C# (FlaUI/UIA + `SendInput` +
    `Windows.Graphics.Capture`), behind the same `DevicePort` contract, proxied
    over IPC. The sidecar never calls Win32 itself.
- **Storage:** JSON files in the sidecar for v0 (conversations, records,
  settings). A SQLite module follows when the JSON store hurts; Room stays
  Android-only.
- **Secrets:** the model key and bridge tokens live in Windows Credential
  Manager on the .NET side and are passed to the sidecar in memory at start.
  The sidecar never writes them to disk.
- **Packaging:** `dotnet publish` + a WiX MSI. MSIX, auto-update and the Store
  are explicitly later.

## Consequences

- Two runtimes ship together (JVM + .NET); the installer is larger than a pure
  .NET or pure JVM app.
- The gate, loop and contracts stay single-copy; the IPC contract becomes the
  only versioned seam between the two halves.
- The Windows device adapter is the long pole (~9–11 weeks) and is scheduled
  after the shell and the phone target, so a usable client ships earlier.
- Windows CI gains a runner for build and smoke tests; the sidecar keeps using
  the existing JVM CI.

## Alternatives considered

- **Compose Desktop (JVM UI).** One runtime and direct `packages/` use, but the
  team's UI skill is .NET and UIA still needs a C# helper, so the result is two
  runtimes with the UI in the less familiar stack.
- **Full .NET port of the loop.** Best native fit and one runtime, but it
  duplicates the gate and the loop forever; parity would rely on fixtures
  alone. Rejected.
- **Electron or Tauri.** A third runtime and a web UI; justified only if a web
  client is also planned.
- **WinUI 3 now.** Better Fluent look and MSIX updates, but a younger ecosystem
  and slower first delivery; deferred, not rejected.

## Spike acceptance (W0)

1. A WPF window starts the sidecar and shows one model turn.
2. One UIA click in Notepad goes through the IPC device proxy.
3. A secure or elevated window fails honestly, with a message the user can act on.
4. The app builds and installs as an MSI on a clean Windows VM.
