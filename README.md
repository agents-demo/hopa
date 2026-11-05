# HOPA — HarmonyOS On-device Phone Agent

HOPA is a GUI agent for **HarmonyOS NEXT / HarmonyOS 6+**. It operates other apps and
websites much like a person would (read the screen, tap, type, scroll, navigate),
runs user scripts inside an **on-device WebAssembly sandbox** (Pyodide + QuickJS,
bundled and offline by default), and **always asks the user before any payment**.

> **Design reference:** the open-source Android agent
> [Mika](https://github.com/wangzan101/Mika) (Apache-2.0). No Mika source code is
> copied into this repository; see [NOTICE](NOTICE). HOPA does **not** use Mika's
> GPL sandbox components (e.g. proot).

## Status

Early scaffold / proof of concept. The first milestone is a PC-driven
device-control proof of concept (`pc-agent` + `HOPA-Bench`).
See [docs/roadmap.md](docs/roadmap.md).

| Area | State |
| --- | --- |
| Dev environment (DevEco Studio 26 / API 26) | see [docs/setup.md](docs/setup.md) |
| `app/` ArkUI shell | scaffold |
| `app/core/` agent loop, tool registry, action gate | scaffold + unit tests |
| `app/capabilities/` web / sandbox / a11y / system | scaffold |
| `pc-agent/` hdc + uitest CLI & MCP server | implemented |
| `agent/` PC reference loop (observe → decide → act → verify → record) | implemented + tests |
| `schemas/` JSON contracts (observation, action, decision, record) | v1 |
| `bench/` HOPA-Bench + 5 tasks | implemented |

## Safety model (non-negotiable)

Every action the agent proposes passes through **one** gate, `ActionExecutor`,
in this order:

```
guards → payment approval → execute → verify → record
```

- **Guards** enforce capability boundaries, app allow-lists, and destructive-action
  limits.
- **Payment approval** is a hard stop. Any action classified as payment (or as a
  step that can trigger payment) must be confirmed by the user. The gate must never
  be weakened, bypassed, or made optional — not by a tool, a model, a script, or a
  future refactor.
- **Verify** compares the observed screen/state with the intended effect.
- **Record** writes an immutable run record for audit and replay.

## Repository layout

```
hopa/
├── app/                      # DevEco Studio project (Stage model)
│   ├── AppScope/
│   ├── entry/                # ArkUI shell: chat, task progress, settings, memory
│   ├── core/                 # HAR: agent loop, tool registry, ActionExecutor (no UI)
│   └── capabilities/         # independent HAR modules
│       ├── web/              # ArkWeb browser agent
│       ├── sandbox/          # hidden ArkWeb + Pyodide/QuickJS (offline)
│       ├── a11y/             # AccessibilityExtensionAbility skeleton (ACL)
│       └── system/           # system intents (alarm, calendar, deep links)
├── pc-agent/                 # Python: hdc + uitest control, CLI and MCP server
├── agent/                    # Python: reference loop, gate, policy, records
├── schemas/                  # v1 JSON contracts shared with the ArkTS core
├── bench/                    # HOPA-Bench tasks + runner
├── docs/                     # setup, architecture, contracts, plan
├── scripts/                  # build / install / test / bench (bash + PowerShell)
├── .github/workflows/        # CI
├── CLAUDE.md                 # conventions for future coding sessions
├── NOTICE
└── LICENSE                   # Apache-2.0
```

## Requirements

- Windows 10/11 64-bit, or macOS; **DevEco Studio 26.0.0** with the bundled
  **HarmonyOS SDK 26.0.0** (API 26).
- **Command Line Tools 26.0.0.851** for headless builds and CI.
- Python **3.11+** and Node **LTS** for `pc-agent/` and `bench/`.
- Emulator: hardware virtualization (Hyper-V + Windows Hypervisor Platform +
  Virtual Machine Platform on Windows), 16 GB+ RAM (32 GB recommended).

Full, reproducible instructions: [docs/setup.md](docs/setup.md).

## Quickstart

```bash
# 1. Build the HAP from the command line
./scripts/build.sh              # or .\scripts\build.ps1 on Windows

# 2. Install on a running emulator/device
./scripts/install-to-device.sh  # or .\scripts\install-to-device.ps1

# 3. Run core unit tests + python checks
./scripts/run-tests.sh          # or .\scripts\run-tests.ps1

# 4. Run the benchmark against the stub model
./scripts/run-bench.sh          # or .\scripts\run-bench.ps1
```

`pc-agent` can also be used directly:

```bash
pc-agent devices
pc-agent apps
pc-agent dump --out layout.json
pc-agent tap 540 1200
pc-agent type 540 900 "hello"
pc-agent screenshot --out screen.jpeg
pc-agent launch com.huawei.hmos.settings
pc-agent mcp          # run as an MCP stdio server
```

The reference loop runs on the PC for M1:

```bash
hopa-agent observe --json
hopa-agent observe --screenshot --out .hopa/screens
hopa-agent run "Open Settings and reach Bluetooth" --steps steps.json
hopa-agent records --path .hopa/runs.jsonl
hopa-agent verify-chain --path .hopa/runs.jsonl
```

The shipped HAP is **ArkTS only**. Python is the development harness; it is not
packaged into the app.

## Documentation

- [docs/setup.md](docs/setup.md) — toolchain, SDK paths, emulator, device, env vars.
- [docs/architecture.md](docs/architecture.md) — layers, the action gate,
  capability boundaries, ACL/permission dependency list.
- [docs/contracts/observation.md](docs/contracts/observation.md) — refs,
  redaction, hashing, truncation.
- [docs/contracts/action.md](docs/contracts/action.md) — kinds, validation,
  payment classification.
- [docs/contracts/errors.md](docs/contracts/errors.md) — error codes and retry
  rules.
- [docs/bench-v0.md](docs/bench-v0.md) — the first five tasks, predicates and
  failure taxonomy.
- [docs/brain.md](docs/brain.md) — JVM brain endpoints and decision contract.
- [docs/status.md](docs/status.md) — honest current state.
- [docs/roadmap.md](docs/roadmap.md) — milestones G1–G4.
- [docs/rebuild-plan.md](docs/rebuild-plan.md) — the delivery plan: phases,
  checkboxes, evidence rules and the definition of finished.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
