# ADR-0007 — Top-level taxonomy and what the word "agent" means

- Status: accepted
- Date: 2026-11-12

## Context

The repository has grown to a HarmonyOS app, a Python bridge, a Kotlin brain
service, a Python evaluation rig and a set of contracts. Two future clients
(Android, Windows) and a possible backend make the top level carry more weight
than it does today.

Three problems motivated this record:

1. `harness/` described both "the quality rig" and, in its `agent/` subfolder,
   something that reads like the product's agent. New readers assume it is the
   thing that ships.
2. The word **agent** names the product loop, the evaluation driver, and a
   package name, so a folder cannot be understood from its name.
3. Nothing stated which top-level folders may be imported by which, so a
   `services/` package could quietly acquire a device dependency.

## Decision

- Top level is: `apps/`, `services/`, `evals/`, `contracts/`, `tools/`, `docs/`.
  Each answers one question before it is opened:

  | Folder | Answers | Ships? |
  |---|---|---|
  | `apps/` | what a person holds | yes |
  | `services/` | what runs with nobody watching | deployable, not shipped to a device |
  | `evals/` | how we know it got better | never |
  | `contracts/` | what both sides may share | data only |
  | `tools/` | how we build and check | never |
  | `docs/` | why it is like this | never |

- **`agent` is a product word**: `apps/harmony/core/agent`, and later
  `services/backend/runtime`. Evaluation code is a *baseline* or a *driver*.
- `evals/` replaces `harness/`. The evaluation driver lives in
  `services/evals/baseline/`; the tasks, runner and scoring in `services/evals/bench/`.
- `services/bridge` and `services/relay` are separate deployables (see ADR-0009).
- Dependency direction is one-way: `apps → contracts`; `services → contracts`;
  `evals → contracts` (and services as a client); **nothing imports `evals/`**.
- `docs/project/archive/` and the retired rebuild plan (tag `rebuild-plan-2026-11-13`)
  are frozen
  evidence: they may keep old paths. Every other document tracks the tree.
- No `utils/`, `helpers/`, `common/`, `misc/`, `shared/` anywhere.

## Consequences

- The repository map in `README.md` and `CONTRIBUTING.md` must equal the table
  above, and a CI check fails when a new top-level folder appears.
- Android and Windows are `apps/android` and `apps/windows`; the platform-specific
  work is a device adapter in the bridge, not a fork of the app.
- Old documents that name `evals/` are updated once, except frozen history.
- The target structure recorded in `docs/design/architecture/target-structure.md` is
  superseded where it disagrees (top-level names, the harness rename).

## Alternatives considered

- **Keep `harness/`.** Rejected: the name says "test rig", not "quality
  measurement", and the `agent/` subfolder actively misleads.
- **`testbed/` or `rig/`.** Honest but less common; `evals/` is the standard split
  next to `tests/` and matches "bench" inside it.
- **Nest evaluation under `tools/`.** Rejected: it is a first-class deliverable
  with its own packages and reports, not a build script.
- **Keep a counts inventory in this ADR.** Rejected: counts rot; they live in the
  plan document instead.
