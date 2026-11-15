# Backend development plan

Status: **week 1 planned, implementation starting.** Written 2026-11-15.
Owners: Amir (lane A: live path), Batya (lane B: stored data and hosting).

The eight-week scope, the gates and the two-engineer split live in
[`weekly-plan.md`](weekly-plan.md). This folder is the execution side of that
plan: one file per week, written before the week starts and ticked with evidence
as it lands.

| Week | File | Status |
|---|---|---|
| 1 · 15–19 Nov | [`week1.md`](week1.md) | planned |
| 2–8 | not written yet | — |

Count a week with:

```bash
python tools/scripts/plan-status.py --plan docs/project/plan/backend
```

Rules, unchanged from the other plans:

- A box is ticked only when the behaviour exists **and** an artifact proves it
  (PR, CI run, test name, deployed trace id). No evidence, no tick.
- `contracts/` changes and their handlers land in the same pull request.
- A week that misses its exit check carries the gap into the next week instead
  of lowering the check.

## Tracking

The RFC for all eight weeks is
[agents-demo/hopa#32](https://github.com/agents-demo/hopa/issues/32). Each weekly
pull request carries `Part of #32` and ticks its row there.
