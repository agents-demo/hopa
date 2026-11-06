# Baseline (2026-11-06)

This is the starting line, not a performance claim. It was produced on a
Windows development machine with **DevEco Studio 6.1.1, HarmonyOS SDK API 24,
and a Pura 90 phone emulator**.

## Environment

| Item | Value |
|---|---|
| OS | Windows 11 |
| Python | 3.12 via `uv` for tests; `py -3` is 3.14 |
| DevEco Studio | 6.1.1 (6.1.1.418) |
| HarmonyOS SDK | 6.1.1, API 24 |
| Command Line Tools | not separately installed |
| hvigor | 6.24.2 |
| ohpm | 6.1.2.268 |
| `hdc` | 3.2.0d |
| Device | Pura 90 emulator, API 24, `127.0.0.1:5555` |
| API 26 | not installed |

## Results

| Check | Result |
|---|---|
| `pytest pc-agent bench` | 75 passed |
| `pytest scripts` (plan tooling) | 8 passed |
| `pytest agent` | 178 passed |
| Agent coverage | 90% (`--cov-fail-under=80`) |
| Combined run | 257 passed |
| Kotlin router + server (`RouterTest`, `ServerTest`) | 37 assertions passed |
| Kotlin knowledge loader (`KnowledgeLoaderTest`) | 14 assertions passed |
| Kotlin prompt contract (`PromptBookTest`) | 16 assertions passed |
| Kotlin skill loader (`SkillLoaderTest`) | 11 assertions passed |
| Brain contract (`/decide` vs schema) | pass |
| Kotlin / JDK | 2.1.0 / 17 |
| `hopa-bench validate --tasks bench/tasks` | 20 tasks valid |
| `pc-agent devices` | works: `127.0.0.1:5555` |
| `pc-agent apps` | works: installed bundle list |
| `pc-agent dump` | **blocked by the emulator lock screen** (`Get window nodes failed`) |
| ArkTS Local Tests | **pass** (`hvigorw test -p module=core@default`) |
| HAP build | **pass**, unsigned (`entry-default-unsigned.hap`) |
| Bench on a device | **3/5** on the Pura 90 emulator; Clock and Notes are not installed |
| Bench with a real model | not run |

## Reproduce

```bash
python -m pip install -e ./pc-agent -e ./bench[dev] -e ./agent[dev]
pytest pc-agent bench agent scripts
python -m hopa_bench validate --tasks bench/tasks
```

ArkTS (PowerShell):

```powershell
$dev='C:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME="$dev\sdk"
$env:JAVA_HOME="$dev\jbr"
$env:PATH="$dev\tools\node;$dev\tools\hvigor\bin;$dev\tools\ohpm\bin;$dev\sdk\default\openharmony\toolchains;$env:PATH"
cd app
ohpm install
hvigorw assembleHap --no-daemon
hvigorw test -p module=core@default --no-daemon -p coverage=false
```

## Gaps this baseline exposes

- Device I/O is partly exercised: `devices` and `apps` work; screen dump is
  blocked until the emulator is unlocked.
- No model call is exercised against a provider. The HTTP client is tested with
  a transport stub.
- The HAP is unsigned, so it has not been installed.
- No payment flow is tested on a real checkout. The safety tests use synthetic
  screens only.
- API 26 is not installed; the project builds on API 24.
