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
| `services/` | services repo | `git filter-repo --path services` carries bridge, relay, wire and brain together |
| `contracts/` | artifact + both repos | published (or tagged) and consumed by version; never copied |
| `apps/` | stays | client code only |
| `tools/scripts` | **split** | app: `build`, `deploy`, `install-to-device`, `build-app-catalog`, `plan-status`. services: `bridges`, `run-agent`, `run-bench`, `run-on-device`, `port-watch`, `repair-chats` |
| `tools/checks` | **split** | `check-tree`/`check-structure` stay with the tree they police; `check-openapi`/`check-render` move with the services (they read service code) |
| `tools/shots` | stays | README media |
| `tools/signing` | stays | app signing, gitignored |
| `docs/` | **split** | `architecture/`, `adr/`, `contracts/`, `guides/` mostly stay; `operations/` for services moves |
| `evals/` | **decide before the split** | see below |

## The evals decision (must be made first)

`evals/bench` and `evals/baseline` import `hopa_bridge` directly (`runner.py`,
`cli.py`, tests). Two honest options:

- **Move `evals/` with the services.** It measures the loop and the device plane;
  simplest and keeps the import. The app repo then has no service dependency.
- **Keep `evals/` in the app repo and make it a client**: it talks to the bridge
  and the backend over their HTTP contracts (`/observe`, `/tap`, `/runs`), as an
  Android or Windows client would. More work, but it proves the contract.

Do not split with the current import in place: that leaves the app repository
depending on a repository it does not contain.

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
- [ ] `evals/` either moves with the services or talks over HTTP; it must not
      import `hopa_bridge` across the split.
- [ ] `tools/scripts` are split into app tools and service tools, with no script
      in the app repository referencing `services/`.
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
