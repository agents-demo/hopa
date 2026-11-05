# Contributing to HOPA

## The evidence rule

A checkbox in [`docs/rebuild-plan.md`](docs/rebuild-plan.md) is done only when
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
python scripts/plan-status.py --lint
python -m hopa_bench validate --tasks bench/tasks
```

For an ArkTS change, also run the core Local Tests on a machine with DevEco.

## Pull requests

- One logical change per PR.
- State the phase and the checkboxes it moves.
- Add or update tests.
- Update the docs that describe the changed contract.
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
