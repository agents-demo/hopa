# ADR-0011 — Where the loop runs, and what a backend owns

- Status: accepted (superseded in part by ADR-0016)
- Date: 2026-11-12

## Context

Today the agent loop runs **on the device** (`apps/harmony/core/agent` driven by
`AgentRuntime`), and the model key lives in the device key store. The bridge is a
device plane, not a product backend: it has no accounts, no run records for a
user, no model keys, and its conversation store is a single JSON file on a PC.

Three forces pull the loop to a server:

1. **Android and Windows** clients should not each re-implement the loop.
2. **Model keys** should not ship on every device.
3. A **separate backend repository** is the stated direction.

## Decision

- **The loop is a server concern.** `services/backend` will own: runs, the loop,
  model access and keys, approvals policy, memory, schedules, and the canonical
  conversation store. It starts life as a plan, not a package (no stub that
  raises `NotImplementedError`).
- **Today's loop stays on the device until that package exists.** No dual loop:
  the device loop is not extracted "in parallel"; the backend takes ownership in
  one move, and the Harmony app becomes a thin client for remote runs.
- **Clients are thin**: they capture, execute actions, render, and never hold a
  model key. Their only coupling is `contracts/` (OpenAPI + schemas).
- **The bridge remains the device plane**, alongside the relay, and never gains
  product logic. It may be deployed per user PC or hosted for a device farm.
- **Shared code is versioned, not copied**: `services/wire` is published as
  `hopa-wire`; `contracts/` is published as a versioned artifact with generated
  clients. A backend, a bridge and a relay depend on a version, not a path.
- The split order is **backend first, then bridge/relay**, because the backend is
  the only piece with user data that needs a migration plan.

## Consequences

- The Harmony app keeps working during the transition: remote runs are a new
  transport under `ModelClient`/`AgentRuntime`, gated by a setting.
- `evals/` moves with the services repository: it imports `hopa_bridge` today, so
  keeping it in the app repo would be a cross-repository dependency. It may later
  become an HTTP client; that is not a precondition for the split.
  `services/evals/baseline` is retired when the backend runs the loop.
- The repo split is mechanical because the folders already are the deployables;
  see `docs/project/operations/repo-split.md`.

## Alternatives considered

- **Extract the loop into `packages/core` and run it in both places.** Rejected:
  two runtimes for one state machine, and a device still needs the key.
- **Keep the loop on-device and let the backend be a sync service.** Rejected:
  it does not solve keys, and Android/Windows would re-implement orchestration.
- **Move everything to one backend monolith including the bridge.** Rejected:
  the bridge needs a device next to it (`hdc`, UIA, adb); that is a different
  deployment and failure domain.
