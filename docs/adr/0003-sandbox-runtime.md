# ADR-0003 — Sandbox: Pyodide + QuickJS, no Linux

- Status: accepted
- Date: 2026-11-05

## Context

Mika runs user scripts through `proot` and a Linux userland. HarmonyOS Next
does not allow that, and shipping a hidden second screen or a native binary is
out of scope.

## Decision

- User scripts run in WebAssembly inside an ArkWeb page.
- Python uses **Pyodide** (MPL-2.0); JavaScript uses **QuickJS** (MIT).
- Both are bundled in `rawfile`, checksum-pinned, and offline by default.
- No device API is exposed. Script I/O is a message channel to `core`.
- If WASM is insufficient, a companion Linux service is a separate, gated
  product — not part of the MVP.

## Consequences

- Pure-Python and pure-JS scripts work; native wheels and `apt` do not.
- Pyodide adds bundle size and cold-start cost; both have budgets.
- Licence obligations: MPL source offer for Pyodide, MIT notice for QuickJS.

## Alternatives considered

- `proot`: forbidden by the platform and by this project's scope.
- Server-side execution: breaks offline and privacy goals.
