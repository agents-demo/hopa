# Evaluation methodology

The benchmark is only useful if a second person can reproduce it.

## Metrics

| Metric | Definition |
|---|---|
| Success | The task's predicate is true at the end |
| Steps | Actions executed |
| Latency p50/p95 | Wall time per step |
| Tokens | Model tokens per task |
| Cost | Tokens × provider price (when known) |
| Failure | One value from the taxonomy |
| Per-app rate | Passed / total for each app |

Failure taxonomy: `target_not_found`, `unsupported_action`, `schema`, `device`,
`predicate_not_met`, `exception`, `step_failed`.

## Targets

| Target | Value | Status |
|---|---|---|
| Bench v1 success (20 tasks) | ≥ 70% | not measured |
| Bench v2 success (50 tasks) | ≥ 85% | not measured |
| Payment refusal | 100% | not measured on a device |
| p95 step latency | ≤ 8 s | not measured |
| Crash-free sessions | ≥ 99% | not measured |

## Run

```bash
bench run --tasks services/evals/bench/tasks --json --out .hopa/bench-v0.json
bench report --input .hopa/bench-v0.json --out docs/design/product/bench-results-v0.md
```

`bench report` prints totals, failure counts, per-app rates and p50/p95 latency.
It does not invent a device result; if no device ran, the report says zero.

## Reproducibility

- Task files are versioned in `services/evals/bench/tasks`.
- The stub model is deterministic.
- Pin the app version, locale, time zone and network state.
- A headline number needs at least 3 runs (30 for a public claim).
- Keep the raw result JSON next to the report.

## Failure attribution

| Layer | Signals |
|---|---|
| Model | wrong action, hallucinated ref, malformed JSON |
| Brain | routing miss, wrong bundle |
| Body | stale ref, missing capability, device error |
| Environment | network, permission dialog, app update |

## Public reporting

- Report the date, device, OS build, app versions and provider.
- Label stub runs as stub runs.
- Never compare a stub run with a real-model run.
- Keep the raw data so the number can be challenged.

## Current status (2026-11-05)

- 20 task files validate.
- Report aggregation is unit-tested.
- No device run has been recorded.
- No real-model run has been recorded.
