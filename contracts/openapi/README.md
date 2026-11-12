# OpenAPI contracts

One file per service, versioned in git, reviewed like code.

| File | Service | Status |
|---|---|---|
| `bridge.v1.yaml` | `services/bridge` (and the pool) | current surface, no `/v1` prefix yet |

## Rules

1. **Same pull request.** A path, method, request or response change edits the
   spec in the same PR that changes the handler. There is no follow-up ticket.
2. **Both directions are checked.** `tools/checks/check-openapi.py` reads the
   `self.path == ...` chain in `bridge.py` / `bridge_pool.py` and fails when a
   handler is missing from the spec *or* a spec path has no handler.
3. **Prefix routes are declared, not hidden.** A route handled by
   `self.path.startswith(...)` (e.g. `/images/`) matches spec paths with the same
   prefix. A routing prefix such as `/d/{serial}` is listed in `x-path-prefixes`.
4. **Auth is part of the contract.** The bootstrap token, the paired token and
   the twelve-hour lifetime are documented per endpoint, not inferred by clients.
5. **Versioning.** The file name carries the major version. The `/v1` path prefix
   is deliberately deferred until a client ships independently of the repository;
   see `docs/reference/protocols.md`.

## Adding an endpoint

1. Add the handler.
2. Add the path (and its schemas) to the spec.
3. Run `python tools/checks/check-openapi.py` — it fails both ways on purpose.
4. If the endpoint needs the pooled routing, document the header it uses.
