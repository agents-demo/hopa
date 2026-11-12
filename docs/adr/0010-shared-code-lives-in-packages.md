# ADR-0010 - Shared code lives in `packages/`, not in a service

- Status: accepted
- Date: 2026-11-12

## Context

Splitting the relay out of the bridge (ADR-0009) ran into a shared dependency:
the WebSocket codec and the tunnel framing are used by both halves. Putting them
in the bridge would make the relay depend on the bridge (and install `hdc` code on
the relay host); putting them in the relay would make every PC install cloud code.
Duplicating 280 lines would drift.

`services/` means "what runs with nobody watching". A library runs nowhere.

## Decision

- Add one top level: `packages/`. A package is code that is **imported**, never
  started. The first is `hopa-wire` (`packages/wire`): the WebSocket codec, the
  tunnel frame format and `TunnelSide`.
- Dependency direction: `apps`, `services`, `evals` may import `packages`;
  `packages` imports only the standard library (plus other `packages`).
  A package never imports a service, an app or the repository's contracts by path.
- `contracts/` stays data (OpenAPI, JSON schemas); `packages/` is code. A change
  to the wire format updates both.
- When the repository splits, `packages/wire` becomes a versioned dependency of
  the backend, bridge and relay repositories - the same role `contracts/` plays
  for clients.

## Consequences

- `check-tree.py` allows `packages/`; the README map and CONTRIBUTING table list
  it as "code both services share".
- `hopa-bridge` and `hopa-relay` both depend on `hopa-wire`. Until the split, the
  install order is documented and CI installs the package first.
- A third deployable that needs the codec does not grow a private copy.

## Alternatives considered

- **Keep `ws.py` in the bridge and let the relay depend on it.** Rejected: the
  relay host would install device code it must never run.
- **Duplicate the codec.** Rejected: the frame format is the wire contract; two
  copies drift silently.
- **Put it under `services/` as a library.** Rejected: `services/` means
  deployable; a folder that does not run would break the rule the taxonomy is for.
