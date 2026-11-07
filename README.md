# HOPA â€” HarmonyOS On-device Phone Agent

HOPA is a GUI agent for **HarmonyOS NEXT / HarmonyOS 6+**. It is built to operate
other apps and websites much like a person would (read the screen, tap, type,
scroll, navigate), it has a built-in browser for web tasks, and it **always asks
the user before any payment**. A WebAssembly sandbox for user scripts (Pyodide +
QuickJS) is designed but **not bundled yet**.

> **Design reference:** the open-source Android agent
> [Mika](https://github.com/wangzan101/Mika) (Apache-2.0). No Mika source code is
> copied into this repository; see [NOTICE](NOTICE). HOPA does **not** use Mika's
> GPL sandbox components (e.g. proot).

> **No background screen.** HOPA drives the visible screen only. It does not use
> a virtual display, and it cannot operate while you are using the phone.

## Status

Working prototype. The PC harness closes the observe â†’ decide â†’ act â†’ verify â†’
record loop, and the signed HarmonyOS app is installed and usable for chat, web
pages, memory, skills and model settings. The accessibility extension is
declared and its permission is granted on the emulator, but this emulator image
has no Settings page to enable a third-party accessibility service, so operating
**other apps on the phone** is still blocked. A retail device needs the
AppGallery ACL approval.

| Area | State |
| --- | --- |
| Dev environment (DevEco Studio 26 / API 26) | see [docs/guides/setup.md](docs/guides/setup.md) |
| `app/` ArkUI app | chat, Web, Apps, Tasks, Settings, Memory; signed debug HAP installed on the emulator |
| `app/core/` agent loop, tool registry, action gate | implemented + hypium tests; OpenAI, Anthropic and Gemini clients |
| `app/capabilities/` web / sandbox / a11y / system | web works via ArkWeb; a11y declared + ACL granted on the emulator (no enable UI); sandbox is a stub |
| `services/pc-agent/` hdc + uitest CLI & MCP server | implemented |
| `harness/agent/` PC reference loop (observe â†’ decide â†’ act â†’ verify â†’ record) | implemented + tests |
| `contracts/schemas/` JSON contracts (observation, action, decision, record) | v1 |
| `harness/bench/` HOPA-Bench 20 task definitions | implemented; 5/7 runnable tasks pass on the emulator |

## Safety model (non-negotiable)

Every action the agent proposes passes through **one** gate, `ActionExecutor`,
in this order:

```
guards â†’ payment approval â†’ execute â†’ verify â†’ record
```

- **Guards** enforce capability boundaries, app allow-lists, and destructive-action
  limits.
- **Payment approval** is a hard stop. Any action classified as payment (or as a
  step that can trigger payment) must be confirmed by the user. The gate must never
  be weakened, bypassed, or made optional â€” not by a tool, a model, a script, or a
  future refactor.
- **Verify** compares the observed screen/state with the intended effect.
- **Record** writes an immutable run record for audit and replay.

## Repository layout

```
hopa/
â”œâ”€â”€ app/                      # DevEco Studio project (Stage model)
â”‚   â”œâ”€â”€ AppScope/
â”‚   â”œâ”€â”€ entry/                # ArkUI shell: chat, task progress, settings, memory
â”‚   â”œâ”€â”€ core/                 # HAR: agent loop, tool registry, ActionExecutor (no UI)
â”‚   â””â”€â”€ capabilities/         # independent HAR modules
â”‚       â”œâ”€â”€ web/              # ArkWeb browser agent
â”‚       â”œâ”€â”€ sandbox/          # hidden ArkWeb + Pyodide/QuickJS (offline)
â”‚       â”œâ”€â”€ a11y/             # AccessibilityExtensionAbility skeleton (ACL)
â”‚       â””â”€â”€ system/           # system intents (alarm, calendar, deep links)
â”œâ”€â”€ services/pc-agent/                 # Python: hdc + uitest control, CLI and MCP server
â”œâ”€â”€ harness/agent/                    # Python: reference loop, gate, policy, records
â”œâ”€â”€ contracts/schemas/                  # v1 JSON contracts shared with the ArkTS core
â”œâ”€â”€ harness/bench/                    # HOPA-Bench tasks + runner
â”œâ”€â”€ docs/                     # setup, architecture, contracts, plan
â”œâ”€â”€ tools/scripts/                  # build / install / test / bench (bash + PowerShell)
â”œâ”€â”€ .github/workflows/        # CI
â”œâ”€â”€ CLAUDE.md                 # conventions for future coding sessions
â”œâ”€â”€ NOTICE
â””â”€â”€ LICENSE                   # Apache-2.0
```

## Requirements

- Windows 10/11 64-bit, or macOS; **DevEco Studio 26.0.0** with the bundled
  **HarmonyOS SDK 26.0.0** (API 26).
- **Command Line Tools 26.0.0.851** for headless builds and CI.
- Python **3.11+** and Node **LTS** for `services/pc-agent/` and `harness/bench/`.
- Emulator: hardware virtualization (Hyper-V + Windows Hypervisor Platform +
  Virtual Machine Platform on Windows), 16 GB+ RAM (32 GB recommended).

Full, reproducible instructions: [docs/guides/setup.md](docs/guides/setup.md).

## Quickstart

```bash
# 1. Build the HAP from the command line
./tools/scripts/build.sh              # or .\tools\scripts\build.ps1 on Windows

# 2. Sign with the SDK's local debug kit and install
./tools/scripts/sign-app.sh --install   # or .\tools\scripts\sign-app.ps1 -Install on Windows

# 3. Run core unit tests + python checks
./tools/scripts/run-tests.sh          # or .\tools\scripts\run-tests.ps1

# 4. Run the benchmark against the stub model
./tools/scripts/run-bench.sh          # or .\tools\scripts\run-bench.ps1

# 5. Summarize a results file
bench report --input .hopa/bench-v0.json --out docs/product/bench-results-v0.md
```

No Huawei account is needed: `tools/scripts/sign-app` uses the OpenHarmony debug
certificates shipped with the SDK, embeds the connected device's UDID, and
regenerates everything under `tools/signing/` (gitignored). See
[docs/guides/build-and-sign.md](docs/guides/build-and-sign.md).

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
pc-agent bridge       # serve the PC-tethered HTTP bridge (token-authenticated)
```

The reference loop runs on the PC for M1:

```bash
hopa-agent observe --json
hopa-agent observe --screenshot --out .hopa/screens
hopa-agent run "Open Settings and reach Bluetooth" --steps steps.json
hopa-agent run "open settings" --model openai --brain http://127.0.0.1:8731
hopa-agent records --path .hopa/runs.jsonl
hopa-agent verify-chain --path .hopa/runs.jsonl
```

With `--brain` (or `HOPA_BRAIN_URL`), the JVM brain picks the first action from
the app knowledge base, then the model drives the rest. See
[docs/reference/brain.md](docs/reference/brain.md).

The shipped HAP is **ArkTS only**. Python is the development harness; it is not
packaged into the app.

## Documentation

- [docs/guides/setup.md](docs/guides/setup.md) â€” toolchain, SDK paths, emulator, device, env vars.
- [docs/architecture/overview.md](docs/architecture/overview.md) â€” layers, the action gate,
  capability boundaries, ACL/permission dependency list.
- [docs/contracts/observation.md](docs/contracts/observation.md) â€” refs,
  redaction, hashing, truncation.
- [docs/contracts/action.md](docs/contracts/action.md) â€” kinds, validation,
  payment classification.
- [docs/contracts/errors.md](docs/contracts/errors.md) â€” error codes and retry
  rules.
- [docs/product/bench-results-v0.md](docs/product/bench-results-v0.md) â€” the first five tasks, predicates and
  failure taxonomy.
- [docs/product/bench.md](docs/product/bench.md) â€” metrics, targets and reproducibility.
- [docs/reference/brain.md](docs/reference/brain.md) â€” JVM brain endpoints and decision contract.
- [docs/reference/knowledge.md](docs/reference/knowledge.md) - app knowledge format and the 27 app files.
- [docs/history/knowledge-triage.md](docs/history/knowledge-triage.md) - the 23 Mika apps classified.
- [docs/reference/bundles.md](docs/reference/bundles.md) - bundle names verified on a device.
- [docs/reference/skills.md](docs/reference/skills.md) â€” the six reusable skill manifests.
- [docs/guides/device-testing.md](docs/guides/device-testing.md) - what the accessibility bridge does and does not do.
- [docs/operations/acl-request.md](docs/operations/acl-request.md) - the accessibility ACL request package.
- [docs/reference/capabilities/browser.md](docs/reference/capabilities/browser.md), [docs/reference/capabilities/system.md](docs/reference/capabilities/system.md), [docs/reference/capabilities/sandbox.md](docs/reference/capabilities/sandbox.md) â€” capability designs.
- [docs/product/ux.md](docs/product/ux.md) â€” screens, states, trust and accessibility.
- [docs/reference/safety.md](docs/reference/safety.md) â€” payment, irreversible actions, limits.
- [docs/reference/abuse.md](docs/reference/abuse.md) â€” refusal taxonomy, CAPTCHA, scraping.
- [docs/reference/threat-model.md](docs/reference/threat-model.md) â€” assets, actors, threats.
- [docs/reference/privacy.md](docs/reference/privacy.md) â€” data inventory, retention, consent.
- [SECURITY.md](SECURITY.md) â€” reporting and key handling.
- [CHANGELOG.md](CHANGELOG.md) â€” version history.
- [docs/operations/release.md](docs/operations/release.md) â€” install, upgrade, rollback, support.
- [docs/history/emulator-crash-2026-11-06.md](docs/history/emulator-crash-2026-11-06.md) â€” emulator freeze analysis.
- [docs/history/status-2026-11-07.md](docs/history/status-2026-11-07.md) â€” honest current state.
- [docs/product/roadmap.md](docs/product/roadmap.md) â€” milestones G1â€“G4.
- [docs/plan/README.md](docs/plan/README.md) â€” the delivery plan: phases,
  checkboxes, evidence rules and the definition of finished.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).



