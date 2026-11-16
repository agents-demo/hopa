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

## Tests

| Suite | Tests |
|---|---|
| `PathSelectorTest` (core) | 3 — intent rewrite, tier on an unchanged action, no selector means empty tier |
| `WindowsSelectorTest` | 7 — aliases, explicit URI, real app, package name, openLink, ref vs coordinates, app function |
| `WindowsIntentsTest` | 5 — case, pass-through, web URL, package name, unknown |
| `ProtocolTest` | `step` carries `tier` |

Sidecar suite: 30 tests, 0 failures. Core suite: 91 tests, 0 failures.

## What is not in P3

- **Automatic fallback.** If a tier is unavailable (for example no host, so
  `system.openLink` is unsupported), the step fails with `E_UNSUPPORTED` and
  records the tier. It does not silently try the next tier. That is the one open
  P3 checkbox, and it is deliberate: a fallback must be visible, not silent.
- **The phone's selector.** With a bridge configured the selector is off, so a
  phone launch keeps its old path until P4.
- Other URI schemes. `file:`, `shell:` and app-specific schemes are refused; the
  allow-list is small on purpose.
