# WASM sandbox

Status: **not bundled.** The capability is a stub. No Pyodide or QuickJS asset
is in `rawfile` yet.

## Runtime

- **Pyodide** (MPL-2.0) for Python-in-WASM.
- **QuickJS** (MIT) for JavaScript-in-WASM.
- Both run inside one `ArkWeb` page; scripts never run as native code.
- Assets are bundled in `rawfile` and checksum-pinned at load.

## Security

- Offline by default; network is a per-run grant and is logged.
- No device API is exposed. Script I/O is a message channel to `core`.
- CPU, memory and wall-clock limits per run.
- Python packages are limited to pure wheels from an allow-list.
- No `proot`, no Linux userland, no native binaries.
- Ten sandbox-escape tests are required before release.

## Budgets

| Budget | Target |
|---|---|
| Cold start | to be measured |
| Memory | to be measured |
| Wall clock per run | to be decided |
| Bundle size | to be decided |

## Licence obligations

- MPL-2.0 source offer for Pyodide.
- MIT notice for QuickJS.
- Keep the NOTICE current when the assets are added.

## Gaps

- Assets not downloaded or bundled.
- No hidden page bridge.
- No limits or escape tests.
- No startup measurement.
- A companion Linux fallback is documented only, never built.
