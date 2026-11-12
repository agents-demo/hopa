# ADR-0012 - Shared service code lives under `services/`, not at the top level

- Status: accepted
- Date: 2026-11-13
- Supersedes: the *location* decision in ADR-0010 (the need for a shared package
  stands; where it lives changes)

## Context

ADR-0010 put the WebSocket/tunnel code in `packages/wire` to avoid a dependency
between the bridge and the relay. That solved the code question and created a
repository question: the plan is for **all services to move to a services
repository**. A top-level `packages/` would either stay behind (leaving service
code in the app repository) or need a second, coordinated move.

Shared code used only by services must leave with the services.

## Decision

- `packages/` does not exist. The shared package is `services/wire`
  (distribution `hopa-wire`, module `hopa_wire`).
- `services/` therefore has two kinds of member: deployables (`bridge`, `relay`,
  `brain`, later `backend`) and libraries (`wire`). The folder name answers "does
  this belong to the server side?", which is the question the repository split
  asks.
- When the split happens, `git filter-repo --path services` carries every service
  and the shared package together; no cross-repository leftover.
- Dependency direction inside `services/`: a deployable may import `wire`;
  `wire` imports only the standard library; `wire` never imports a deployable.

## Consequences

- `check-tree.py` fails if a top-level `packages/` reappears.
- The README map and `layers.md` describe `services/wire` as "shared, not
  deployed".
- `hopa-wire` is still a versioned dependency for the future split; only its path
  moved.

## Alternatives considered

- **Keep `packages/` and move it later.** Rejected: it is a second migration and
  a chance for the app repository to keep server code.
- **Put `wire` inside `bridge` and let the relay depend on `bridge`.** Rejected in
  ADR-0010 and still wrong (a relay host installing device code).
- **Duplicate the codec.** Rejected: the wire format would drift.
