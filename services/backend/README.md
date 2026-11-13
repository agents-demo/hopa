# HOPA backend

**Status: reserved.** No package yet, and deliberately no stub. ADR-0011 records
why: a `runtime/` that raises `NotImplementedError` would be a second loop's
shadow, not a start.

## What belongs here

The server side of HOPA, once the loop moves off the device:

| Area | Owns |
|---|---|
| `api/` | `/v1` endpoints for clients (sessions, runs, approvals) |
| `runtime/` | the loop: observe → decide → act → verify → record |
| `sessions/` | the canonical conversation store and sync |
| `models/` | provider clients, model keys, budgets |
| `tools/` | action validation and the approval gate |
| `memory/` | facts and skills |
| `schedules/` | timers and recurring work |

## What must never be here

- No `hdc`, `adb`, UI Automation, or any device transport. The bridge owns that
  (`services/bridge`).
- No copied client code; clients talk over `contracts/`.
- No second copy of `hopa-wire`; it is a dependency.

## Shape

```
services/backend/
├─ pyproject.toml            # hopa-backend
├─ src/hopa_backend/
│  ├─ api/                   # FastAPI (or stdlib) over contracts/openapi/backend.v1.yaml
│  ├─ runtime/               # the loop, ported from services/evals/baseline
│  ├─ sessions/              # store + migrations
│  ├─ models/                # provider clients, keys from the environment
│  ├─ tools/                 # gate + executor
│  ├─ memory/
│  └─ schedules/
└─ tests/                    # mirrors src/
```

`contracts/openapi/backend.v1.yaml` is written **before** the first handler, the
same rule the bridge and relay follow (`contracts/openapi/README.md`).

## First steps when work starts

- [ ] Write `contracts/openapi/backend.v1.yaml`: `/v1/health`, `/v1/sessions`,
      `/v1/runs`, `/v1/approvals`, with the client versioning rule.
- [ ] Port the loop from `services/evals/baseline` (it is the reference implementation) and
      point it at the bridge for actions.
- [ ] Move model keys out of the device key store; the app stops calling providers.
- [ ] Add a migration story for `sessions` before the first deployment.
- [ ] `evals/` becomes a client of this service, not a second loop.

## Where the code is today

The loop runs on the device (`apps/harmony/core/agent`, driven by
`AgentRuntime`); the bridge is the device plane; the relay is transport. See
`docs/architecture/overview.md` and `docs/operations/repo-split.md`.
