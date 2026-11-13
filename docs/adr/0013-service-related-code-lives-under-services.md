# ADR-0013 - Everything service-related lives under `services/`

- Status: accepted
- Date: 2026-11-13
- Supersedes: the top-level `evals/` entry of ADR-0007, and the placement of
  service tools

## Context

ADR-0011 and the repository-split runbook say the services will leave for their
own repository. `evals/` imports `hopa_bridge`, and several tools drive
`python -m hopa_bridge` or read service code. While they sit at the top level, the
future split is a multi-path operation and the app repository keeps service code.

The owner's rule: **everything related to services moves under `services/`**, so
the split is one path.

## Decision

- `services/` contains both deployables and the things that belong to them:
  - deployables: `bridge`, `relay`, `brain`, (later) `backend`;
  - shared library: `wire`;
  - evaluation: `evals/bench`, `evals/baseline`;
  - service tools: `tools/scripts` (bridges, run-agent, run-bench, run-on-device,
    port-watch, repair-chats) and `tools/checks` (openapi, render).
- Top level is `apps/`, `services/`, `contracts/`, `tools/`, `docs/` (plus
  `.github`). A returning top-level `evals/` is a violation.
- `tools/` keeps only app tooling: build, deploy, install, catalog, plan status,
  tests for those checks, shots, signing.
- Docs stay at `docs/` until the split: they are the repository's index and many
  links cross the boundary. At the split, the service docs move with the services
  (listed in `docs/operations/repo-split.md`).

## Consequences

- `git filter-repo --path services` carries the services, the shared package, the
  evaluation suite and the service tools in one move.
- The app repository keeps no import of `hopa_bridge`.
- CI paths and scripts use `services/evals/...` and `services/tools/...`.

## Alternatives considered

- **Keep `evals/` top level and move it later.** Rejected: it is the exact
  leftover the owner objected to.
- **Move `docs/` under services now.** Rejected for now: it would break
  cross-cutting links; the runbook assigns the service docs for the split step.
