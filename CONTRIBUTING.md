# Contributing to HOPA

## The evidence rule

A checkbox in [`docs/plan/README.md`](docs/plan/README.md) is done only when
the stated verification passes on the stated target. Append the evidence on the
same line:

```markdown
- [x] `pytest agent` green (evidence: CI run 123456)
```

Accepted evidence: a CI run, a PR number, a test name, a device screenshot, a
bench report with a date. "Code exists" is not evidence.

Never tick the unchecked half of a decision pair. The checker treats a pair with
one checked side as **decided**; both checked is an error.

## Before you open a PR

```bash
python -m pip install -e ./pc-agent -e ./bench[dev] -e ./agent[dev]
ruff check pc-agent bench agent
ruff format --check pc-agent bench agent
pytest pc-agent bench agent
python tools/scripts/plan-status.py --lint
python tools/scripts/build-app-catalog.py --check
python -m hopa_bench validate --tasks evals/bench/tasks
```

For an ArkTS change, also run the core Local Tests on a machine with DevEco.

## Adding an app or a site

1. Copy `services/brain/knowledge/apps/settings/APP.md` as a template.
2. `bundle` must be a name checked on a device or AppGallery. If it is not
   checked yet, write `bundle: UNCONFIRMED`; never guess a package.
3. Add `bundle_verified: YYYY-MM-DD` only after a launch on a device.
4. Add `ability:` (the launcher ability) if the app should be openable from the
   Apps tab.
5. Run `python tools/scripts/build-app-catalog.py` to regenerate the in-app catalogue.
6. Sites follow the same rule with `domains` in `SITE.md`.

The generated `AppCatalog.ets` is committed; CI fails if it is stale.

## Pull requests

- One logical change per PR.
- State the phase and the checkboxes it moves.
- Add or update tests.
- Update the docs that describe the changed contract.

### The front door moves with the change

`README.md`, its banner (`docs/media/banner-*.svg`) and `CHANGELOG.md` are part
of the change, not a follow-up task:

- A new capability, mode or setting gets its line in the README where a reader
  would look for it.
- A changed promise, tagline or product name changes the banner **and** the
  README hero in the same commit.
- A removed or renamed feature loses its README line; nothing left saying “soon”
  about something that already shipped, or “works” about something that does not.
- A screenshot that shows an older UI is replaced or deleted, never kept as
  decoration.
- When the banner is re-rendered, keep a proof image (for example
  `tools/shots/banner-duo.png`) so the change can be reviewed without opening an
  editor.

A PR that changes behaviour without touching the front door is incomplete.

- Do not include secrets, keys, screenshots of real accounts or patient data.

Use the PR template in `.github/PULL_REQUEST_TEMPLATE.md`.

## Safety rules

- Every action goes through `DeviceExecutor` (PC) or `ActionExecutor`
  (device). Do not call a capability directly.
- Payment classification comes from the screen and the action, never from a
  model flag.
- A denied action is recorded and never retried through another path.
- Emergency numbers are blocked.
- New action kinds must be added to the schema, the validator, the policy and
  the tests in the same PR.

## Where does a new file go?

Ask which top level answers the question, then pick the layer (ADR-0007):

| The new thing is... | Top level |
|---|---|
| a screen, a widget, a platform adapter | `apps/` (`harmony/`, later `android/`, `windows/`) |
| a long-running service, a device driver, a relay | `services/` (`bridge/`, `relay/`, `brain/`, later `backend/`) |
| a task, a score, a reference driver | `evals/` (`bench/`, `baseline/`) |
| a wire format both sides share | `contracts/` (`openapi/`, `schemas/`) |
| a build, sign or check step | `tools/` (`scripts/`, `checks/`, `signing/`) |
| why something is the way it is | `docs/` (`adr/`, `architecture/`, `guides/`) |

Inside the Harmony app, `docs/architecture/layers.md` has the second table
(core / capabilities / entry). Two rules are absolute: `core` imports no
`@kit.*`, and nothing imports `evals/` - it is a measuring instrument, not a
library.

## Style

- Python: ruff, line length 100, `from __future__ import annotations`.
- ArkTS: strict mode, no `any` in core, 2-space indent.
- Markdown: one sentence per line where practical; links relative to the repo.
- Commit messages: imperative, one line, optional body with the reason.

## Commit and branch

- `main` is protected; work happens on `feat/…`, `fix/…`, `docs/…`.
- Commit subjects: `area: short imperative` (for example
  `agent: reject stale refs`).
- Do not rewrite published history.

## Licence

Contributions are Apache-2.0. By opening a PR you confirm you have the right to
submit the code. Do not copy GPL, AGPL or source-available code.
