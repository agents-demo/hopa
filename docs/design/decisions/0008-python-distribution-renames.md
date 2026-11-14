# ADR-0008 — Python distribution renames and the one-release CLI aliases

- Status: accepted
- Date: 2026-11-12

## Context

Three Python distributions ship from this repository, and their names describe a
past layout:

| Distribution | Package | Console script | Path today |
|---|---|---|---|
| `hopa-bridge` | `hopa_bridge` | `pc-agent` | `services/bridge` |
| `hopa-baseline` | `hopa_baseline` | `hopa-baseline` | `services/evals/baseline` |
| `hopa-bench` | `hopa_bench` | `bench` | `services/evals/bench` |

The command names are user-visible: `docs/guides/harmony/pc-bridge.md`,
`docs/guides/harmony/setup.md`, `tools/scripts/run-*.ps1|sh`, the laptop's
`BridgeWizard.ets` (it prints `python -m hopa_bridge bridge …`), the MCP server
name and the SBOM all carry them.

Renaming a distribution is not a pure folder move: pip keeps the old
`*.dist-info`, the old `.pth` file and the old console wrapper, so a stale
`pc-agent.exe` can make a rename look successful when it is running old code.

## Decision

- `services/bridge`: distribution **`hopa-bridge`**, package **`hopa_bridge`**,
  console scripts **`hopa-bridge`** and, for one release, **`pc-agent`**.
  **`pc-agent` stays the primary name in the scripts and docs for this release**;
  the alias exists so nothing breaks on the day of the move.
- `services/evals/baseline`: distribution **`hopa-baseline`**, package **`hopa_baseline`**,
  console scripts **`hopa-baseline`** and, for one release, **`hopa-baseline`**.
- `services/evals/bench`: distribution and script stay **`hopa-bench`** / **`bench`**.
- User-visible strings change with the package: `cli.py` `prog=` and error
  prefixes, `mcp_server.py` `SERVER_NAME`, the wizard command in
  `BridgeWizard.ets`, and the tests that assert those literals.
- The rename is **one atomic commit** per package: folder move, imports,
  `pyproject.toml`, CI paths, scripts and docs together. After it, a fresh
  install is mandatory before anything is verified.
- The follow-up release removes the aliases and updates `run-*.ps1|sh` to the new
  executable name; that is tracked in the refactor plan, not here.

## Consequences

- `pip uninstall -y hopa-bridge hopa-baseline hopa-bench` is a required step of the
  refactor, before the alias can be trusted.
- The SBOM, `CHANGELOG.md` and `.env.example` mention distribution names and move
  with them.
- A machine that still has the old distributions installed will report a version
  for a package that no longer exists on disk; `pip list` is the detector.

## Alternatives considered

- **Keep `hopa_bridge` while the folder says `bridge`.** Rejected: the import
  name is the first thing a reader sees, and `pc-agent` is not what it does for
  Android or Windows.
- **Rename the CLI immediately.** Rejected: the wizard, four PowerShell scripts and
  two shell scripts resolve `pc-agent.exe`; a one-release alias is the cheaper,
  reversible path.
- **Publish both distributions under new names without aliases.** Rejected: the
  wizard would break for anyone who copies its printed command.
