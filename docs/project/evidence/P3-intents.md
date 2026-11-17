# P3 — the path selector (intent first)

Date: 2026-11-16. Host: Windows 11 (10.0.22631), .NET 8.0.428, JDK 17.

## What P3 added

| Thing | Where |
|---|---|
| Four tiers and a planned action | `packages/core/.../gate/PathSelector.kt` |
| The selector runs before the gate and the record keeps the chosen action | `ActionExecutor.execute` |
| `tier` on every step | `RunRecord.tier`, the schema, `RunRecordSerializer`, `Protocol.step` |
| Windows tier table | `apps/windows/sidecar/.../WindowsPathSelector.kt` |
| Settings aliases → URIs | `apps/windows/sidecar/.../WindowsIntents.kt` |
| `system.openLink` on Windows | `HostSystem`, `HostDevice.openLink`, `WindowsDevice.OpenLink` |
| Scheme allow-list | `http`, `https`, `ms-settings`; everything else is refused |
| Stub trigger for the gate | "wifi" → `ui.launch app=wifi`, rewritten to the URI |
| Ordered tier plans and visible fallback | `PathSelector.plan`, `WindowsPathSelector.plan`, `ActionExecutor.onFallback` |

The rewrite happens **before** the gate, so approval, the record and the step
event all describe the action that actually ran (`system.openLink`), not the
launch the model proposed.

## The gate: "open wifi settings"

`Hopa.Windows.exe --turn "open wifi settings" --out …`

```
sidecar: [sidecar] turn r-789f88d7… in c-8272…: open wifi settings
device: observed 350 nodes in 'Code'
device: opened ms-settings:network-wifi (foreground=ApplicationFrameHost)
device: observed 96 nodes in 'ApplicationFrameHost'
step 0: system.openLink tier=intent executed=True
HOPA: Stub answered: "open wifi settings".
step #0 system.openLink [read] approved= executed=True verified=True error= hash=sha256:186
chain: ok
```

The model proposed `ui.launch app=wifi`; the selector made it
`system.openLink url=ms-settings:network-wifi`, tier `intent`. The observation
changed from a 350-node editor to a 96-node Settings window, so the step is
verified — no click sequence anywhere.

## The host check: `--p3-check`

```
scheme refused: refused: the 'file' scheme is not allowed; only http, https and ms-settings
scheme refused: refused: the 'shell' scheme is not allowed; only http, https and ms-settings
open: opened ms-settings:network-wifi (foreground=ApplicationFrameHost)
observe: app=ApplicationFrameHost nodes=96
foreground: ApplicationFrameHost
```

## Automatic fallback (closed 2026-11-17)

A selector can now return an ordered list of candidate paths. `WindowsPathSelector.plan`
puts the URI (`intent`) first and keeps the original `ui.launch` (`uia`) as a
second candidate. `ActionExecutor` tries them in order: an
`UnsupportedOperationException` means the tier is unavailable, not that the
device failed. It logs the tier it left and moves on, so the fallback is never
silent. A device error is never retried, and the person is asked for approval
once, before the first tier runs — a fallback retries a path, never a decision.
Still one record per step: the tier on the step is the one that actually ran.

Headless, with no host and therefore no system port:

```
[sidecar] turn cli-1 in c-2016ef2e-…: open wifi settings
[sidecar] tier intent unavailable (E_UNSUPPORTED); falling back to uia
{"type":"turn.end",…,"steps":[{"action":{"kind":"ui.launch","app":"wifi"},
  "classification":"read","tier":"uia","executed":false,"error":"E_UNSUPPORTED",…}],
 "narration":["Open wifi failed: E_UNSUPPORTED"]}
```

The first tier was refused with `E_UNSUPPORTED`, the tier that actually ran is
recorded, and the fall-through is a visible log line. Both tiers are unavailable
in headless mode, so the step honestly fails; with a device attached the second
tier launches the app and `HeadlessTurnTest` proves it (`launches = ["wifi"]`,
`tier = uia`, `executed = true`).

## Tests

| Suite | Tests | Notes |
|---|---|---|
| `PathSelectorTest` (core) | 6 | intent rewrite, unchanged action, empty tier; +3 fallback cases |
| `WindowsSelectorTest` | 10 | aliases, URI, real app, package, openLink, ref vs coords, app function; +3 plan cases |
| `WindowsIntentsTest` | 5 | case, pass-through, web URL, package name, unknown |
| `HeadlessTurnTest` | 8 | P1 gate; +1 no-system-port fallback |
| `ProtocolTest` | 5 | `step` carries `tier` |

Measured from the JUnit XML: core 22 suites / 92 tests, sidecar 8 suites / 41
tests, 0 failures. These replace the earlier 91/30 estimates in this file.

## Still not in P3

- **The phone's selector.** With a bridge configured the selector is off, so a
  phone launch keeps its old path until P4.
- Other URI schemes. `file:`, `shell:` and app-specific schemes are refused; the
  allow-list is small on purpose.
