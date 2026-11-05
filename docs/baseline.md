# Baseline (2026-11-05)

This is the starting line, not a performance claim. It was produced on a
Windows development machine with **no HarmonyOS SDK, no `hdc`, no emulator and
no phone**.

## Environment

| Item | Value |
|---|---|
| OS | Windows 11 |
| Python | 3.12 via `uv` for tests; `py -3` is 3.14 |
| DevEco Studio | not installed |
| HarmonyOS SDK / CLT | not installed |
| `hdc` | not found |
| Device | none |

## Results

| Check | Result |
|---|---|
| `pytest pc-agent bench` | 56 passed |
| `pytest scripts` (plan tooling) | 8 passed |
| `pytest agent` | 143 passed |
| Agent coverage | 89% (`--cov-fail-under=80`) |
| Full harness | 216 passed |
| Kotlin router + server (`RouterTest`, `ServerTest`) | 34 assertions passed |
| Brain contract (`/decide` vs schema) | pass |
| Kotlin / JDK | 2.1.0 / 17 |
| `hopa-bench validate --tasks bench/tasks` | 5 tasks valid |
| `pc-agent devices` | fails with `hdc not found` (expected) |
| ArkTS Local Tests | not run (no SDK) |
| HAP build | not run (no SDK) |
| Bench on a device | not run |
| Bench with a real model | not run |

## Reproduce

```bash
python -m pip install -e ./pc-agent -e ./bench[dev] -e ./agent[dev]
pytest pc-agent bench agent scripts
python -m hopa_bench validate --tasks bench/tasks
```

## Gaps this baseline exposes

- No device I/O is exercised. Every device path is unit-tested against a fake.
- No model call is exercised against a provider. The HTTP client is tested with
  a transport stub.
- No ArkTS code is compiled.
- No payment flow is tested on a real checkout. The safety tests use synthetic
  screens only.
