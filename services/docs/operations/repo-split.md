# Splitting the repository

Status: **runbook, not executed.** The tree is already split by deployable
(ADR-0007), so this is a move, not a rewrite. Do it when the backend loop exists
(ADR-0011), not before.

## Target repositories

| Repository | Contains | Ships |
|---|---|---|
| `hopa` (stays) | `apps/harmony`, later `apps/android`, `apps/windows`; app-side `tools/` | the client apps |
| `hopa-services` | all of `services/` (`bridge`, `relay`, `wire`, `brain`, later `backend`) | device plane, relay, loop |
| `hopa-backend` (later, from `services/backend`) | the loop, accounts, keys, memory, schedules | the backend |
| `hopa-contracts` (data) | `contracts/` | versioned OpenAPI + schemas, generated clients |

Start with **one** services repository, not four: the pieces share `services/wire`
and are easier to keep honest together. Split `backend` out later if its release
cadence differs.

## Folder-by-folder, at the first split

| Folder | Goes to | Note |
|---|---|---|
| `services/` | services repo | one path now carries bridge, relay, wire, brain, evals and the service tools |
| `contracts/` | artifact + both repos | published (or tagged) and consumed by version; never copied |
| `apps/` | stays | client code only |
| `tools/scripts` | split (done) | app: `build`, `deploy`, `install-to-device`, `build-app-catalog`, `plan-status`. services: `services/tools/scripts/*` |
| `tools/checks` | split (done) | `check-tree`/`check-structure`/`check-links` stay; `services/tools/checks/` holds openapi and render |
| `tools/shots` | stays | README media |
| `tools/signing` | stays | app signing, gitignored |
| `docs/` | split (done) | service docs already in `services/docs/`; shared architecture, contracts and policy stay in `docs/` |
| `services/evals/` | services repo (already inside) | imports `hopa_bridge`; the app repo never sees it |

## Decisions taken

- **`evals/` moves with the services.** It imports `hopa_bridge` (`runner.py`,
  `cli.py`, tests), so it belongs where that code lives. The app repository then
  has no service dependency. It can later become an HTTP client, but that is not
  a precondition for the split.
- **`tools/` is split by what it drives.** A script that runs
  `python -m hopa_bridge`, installs `./services/bridge`, or reads service code
  moves with the services. A script that only builds/installs the app stays.
  No script in the app repository may reference `services/` by path.
- **`docs/` is split by subject.** Service docs (bridge, relay, wire, protocols,
  operations, data-flow, service ADRs) move; product, UX, setup, signing and the
  app ADRs stay.
- **`contracts/` is shared by version**, not copied and not owned by either side.

## The tools decision (same rule)

A script that runs `python -m hopa_bridge` or installs `./services/bridge` is a
service tool and must move with the service. In the app repository, it becomes
either an HTTP call to a running service or a documented external step. A script
that stays must not reference `services/` by path.

`services/brain` (Kotlin) moves with the backend or becomes its own service; it is
not part of this runbook.

## What must be true before the split

- [ ] `services/wire` is published (or consumed from git) with a version, and
      the bridge/relay depend on that version, not a path.
- [ ] `evals/` moves with the services (decided); the app repo keeps no import
      of `hopa_bridge`.
- [ ] `tools/scripts` and `tools/checks` are split, with no script in the app
      repository referencing `services/`.
- [x] Service docs are in `services/docs/`; the app repo keeps product, setup,
      signing and the shared architecture/contracts/policy docs.
- [ ] `contracts/` is consumed as a versioned artifact; clients are generated
      from it.
- [ ] No service imports another by path: `check-structure.py` already rejects
      `hdc` outside the adapter; add an import rule for sibling packages.
- [ ] Each service has its own README, pyproject and tests (done for bridge,
      relay, wire).
- [ ] CI for each service is path-filtered (`paths:` in GitHub Actions), so a
      docs change does not rebuild a service.

## Order

1. **Backend** (only if it exists): it owns user data, so it needs a schema and a
   migration story before it has a repository.
2. **Wire**: publish first; both services depend on it.
3. **Bridge** and **Relay**: independent after wire; the relay is one deployable
   (see `render.yaml`).
4. **Apps**: last; they only need `contracts/` and a backend URL.

Do not split the apps repository while the Harmony app still hosts the loop; that
would leave the loop in a client repo, which ADR-0011 forbids.

## Mechanics

Use history-preserving moves, one repository per step:

```bash
# in a scratch clone of hopa
git filter-repo --path services/bridge --path-relative-to=. \
                 --to-subdirectory-filter=.
# then push that history into the new repository's main
```

For `services/wire`, filter on `services/wire` and add the package's own
`README.md`/`pyproject.toml` at the root of the new repository:

```bash
git filter-repo --path services/wire --path-relative-to=services/wire
```

Keep `contracts/` in a repository of its own **only when a client ships on its
own schedule**; until then a tag in `hopa-backend` is enough.

## Per-repository CI

| Repo | Jobs |
|---|---|
| `hopa` | HAP build, core tests, evals against a running backend |
| `hopa-backend` | unit tests, migrations, contract check against `hopa-contracts` |
| `hopa-bridge` | pytest, adapter tests on a fake, one hardware smoke on a self-hosted runner |
| `hopa-relay` | pytest, container build, `/health` smoke |
| `hopa-wire` | pytest, publish on tag |
| `hopa-contracts` | OpenAPI lint, client generation, breaking-change check |

## What keeps the pieces honest

- `contracts/openapi/*.yaml` is the only cross-repo truth; a path change is a
  versioned change.
- `hopa-wire` owns framing; a change there is a version bump.
- `check-openapi.py` and `check-tree.py` stay in `hopa` and run against the
  checked-out siblings in an integration job; each split repo keeps its own unit
  rules.
- The evaluation suite moves to `hopa` and points at a deployed backend; it must
  never import backend internals.

## Rollback

Until a repository is deleted, the split is reversible by pushing the original
monorepo tag. Tag the commit before the first split:
`git tag pre-split-$(date +%Y%m%d)`.
