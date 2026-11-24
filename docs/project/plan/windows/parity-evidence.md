# Windows parity evidence

W11 proves [parity.md](parity.md) with artifacts instead of assertions. Every
row should end with either a test, a transcript, or a screenshot pair that a
reviewer can open.

## Layers

| Layer | Command | Artifact |
|---|---|---|
| Unit | `dotnet test apps/windows/Hopa.Windows.Tests -c Debug` | test log, **105** tests |
| Integration | `dotnet test apps/windows/Hopa.Windows.IntegrationTests -c Debug` | test log, **10** tests |
| Sidecar | `gradlew -p apps/windows/sidecar test` | test log, engine/transport/data |
| Desktop | `tools/scripts/windows-desktop-checks.ps1 -Output out/windows-desktop` | transcripts + PNGs |

The desktop script is the only layer that needs an interactive Windows session.
Hosted runners are session 0 and cannot produce it; see
[desktop-ci.md](../../../guides/windows/desktop-ci.md).

## Screenshots

| Surface | Command | Files |
|---|---|---|
| Settings hub, every page | `Hopa.Windows.DevTools.exe --shot-settings-pages <dir>` | `windows-settings-<page>.png` × 17 |
| W4 window and tray | `--w4-check <dir>` | `windows-w4.png`, `w4-check.txt` |
| W6 chat | `--shot-chat <dir>` | `windows-w6-chat.png` |
| W6 approval/steps | `--shot-components <dir>` | `windows-w6-approval.png`, `windows-w6-steps.png` |
| W6 frame | `--shot-frame <path>` | `windows-frame.png` |
| Settings dialog | `--shot-settings <path>` | `windows-settings.png` |
| Keyboard order | `--keyboard-check <dir>` | `keyboard-check.txt` |

## Transcripts

| Claim | Command | Check |
|---|---|---|
| UIA hash stable, blind type refused | `--w3-check <path>` | `hash stable ... True`, `blind type: refused` |
| DevicePort contract | `--p2-check <path>` | stale ref, readback, apps, screenshot |
| App matrix | `--matrix-check <path>` | Notepad/Calculator/Explorer/Chrome/Code |
| Lock/elevation | `--p2-wait <path> 60 [elevated]` | human-only refusal transcript |
| Windows tier order | `--turn "open wifi settings"` | `tier=intent` in the log |
| Plan-first | `--turn ... --approval`/PlanWindow | `plan[]` in `turn.end`, then approved replay |
| Replay | second `--turn` with the same goal | recipe step in the run record |
| Instant commands | `--turn "open notepad"` | one launch step, no model call |
| Vision | a model that accepts images | frame in the request; blocked until model available |

## Pairing with Android

Android screenshots come from the existing Roborazzi suite:

```powershell
cd apps/android
./gradlew :screenshots:verifyRoborazziDebug --no-daemon
```

The reviewer pairs each Android screen in [parity.md](parity.md) with the
Windows file from the table above. Rows marked `adapt` explain the desktop form
in the matrix; rows marked `not-applicable` carry the platform reason.

## Current gaps

- The settings-page set is complete; the other Windows screens still need the
  same one-file-per-surface treatment.
- Android and Windows screenshots are not yet stored in one artifact tree.
- The signed-form P5 transcript needs a real form, not a synthetic screenshot.
- A real vision round-trip waits for an image-capable model.
- The desktop CI job is ready but its self-hosted runner is not registered.
