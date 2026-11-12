# Splitting the repository

Status: **runbook, not executed.** The tree is already split by deployable
(ADR-0007), so this is a move, not a rewrite. Do it when the backend loop exists
(ADR-0011), not before.

## Target repositories

| Repository | Contains | Ships |
|---|---|---|
| `hopa` (stays) | `apps/harmony`, later `apps/android`, `apps/windows`; `evals/` | the client apps |
| `hopa-backend` | `services/backend` | the loop, accounts, keys, memory, schedules |
| `hopa-bridge` | `services/bridge` | device plane (hdc/adb/UIA adapters) |
| `hopa-relay` | `services/relay` | the cloud relay |
| `hopa-wire` (library) | `packages/wire` | published versioned package |
| `hopa-contracts` (data) | `contracts/` | versioned OpenAPI + schemas, generated clients |

`services/brain` (Kotlin) moves with the backend or becomes its own service; it is
not part of this runbook.

## What must be true before the split

- [ ] `hopa-wire` is published (or consumed from git) with a version, and
      `hopa-bridge` / `hopa-relay` depend on that version, not a path.
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

For `packages/wire`, filter on `packages/wire` and add the package's own
`README.md`/`pyproject.toml` at the root of the new repository:

```bash
git filter-repo --path packages/wire --path-relative-to=packages/wire
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
