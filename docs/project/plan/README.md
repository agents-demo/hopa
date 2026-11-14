> The earlier M1-M6 rebuild plan is retired (ADR-0014) and lives in git at the
> tag `rebuild-plan-2026-11-13`; this file is the active plan. Count it with
> `python tools/scripts/plan-status.py` (default path) or `--plan docs/project/plan`.

The **Android development plan** is a separate, later plan:
[`android/README.md`](android/README.md) (ADR-0016, ADR-0017). It is not part of
this refactor's gate; this plan only prepares its decisions, contracts and folder.

The **Windows development plan** follows it:
[`windows/README.md`](windows/README.md) (ADR-0021). It starts at W0 once the
Android gates close.

# Refactor plan: apps, services, evals

Status: **revised after critique; execution starts at R0.**
Written 2026-11-12; revised same day (critique pass recorded in §9).
Scope: structure and naming only. No behaviour change, no new platform code.

Three futures this prepares for:

1. **Android HOPA** and **Windows HOPA** as additional `apps/`.
2. The **bridge as a real backend** (device plane + relay), later a separate repo.
3. **services/evals/** as the place quality is measured, instead of `harness/`.

Counted on its own, not against the old M-milestone gate: `plan-status.py` reads
this file and ignores subfolders (so `android/` has its own count). Run:

```bash
python tools/scripts/plan-status.py --plan docs/project/plan
python tools/scripts/plan-status.py --plan docs/project/plan --lint
```

## 0. Rules

Where a box says `commit <sha>`, the change and its tests are in that commit;
`(evidence: verified in this repository, 2026-11-13)` means a file or check in
the tree proves it.


- Every `[x]` carries `(evidence: ...)` on the same line: command output, CI run
  id, PR number, or device screenshot. No evidence, no tick.
- One phase = one mergeable change. **Each rename is one atomic commit**: the
  move, the imports, the pyproject edit and the CI paths land together, because
  CI installs by path and a "move only" commit cannot be green.
- `git mv` for tracked files, so blame survives. Caches and `.idea` are untracked
  and are cleaned, not moved.
- New paths exist before old ones only where a transition needs both (console
  script aliases). Everywhere else the old path is gone in the same commit.
- `docs/project/archive/` and the retired rebuild plan (tag `rebuild-plan-2026-11-13`) are **frozen**. They may
  keep old paths; everything else must not.
- **`agent` is a product word.** Evaluation code is a *baseline* or a *driver*.
- No junk drawers: `utils/`, `helpers/`, `common/`, `misc/`, `shared/`.
- `docs/design/architecture/layers.md` remains the authority for import direction.
- Decision boxes come in pairs with the literal marker
  `(one of the two must be checked)`; conditional work is prose.

## 1. Target tree

```
hopa/
├─ apps/                    # what a person holds
│  ├─ harmony/              # DevEco workspace (exists)
│  ├─ android/              # README first (R9)
│  └─ windows/              # README first (R9)
├─ services/                # deployables, shared code, evaluation, service tools
│  ├─ bridge/               # device plane (R3)
│  ├─ relay/                # cloud relay server half (R4)
│  ├─ wire/                 # shared WebSocket/tunnel code, not deployed (ADR-0012)
│  ├─ brain/                # Kotlin knowledge router (exists, unchanged)
│  ├─ backend/              # reserved: README + ADR-0011, no package yet
│  ├─ evals/                # bench/ + baseline/ (ADR-0013)
│  ├─ tools/                # scripts/ + checks/ that drive the services
│  └─ docs/                 # guides, protocols, brain, bench, service ADRs
├─ contracts/
│  ├─ openapi/              # bridge.v1.yaml (R5)
│  └─ schemas/              # 4 JSON schemas (exists)
├─ tools/                   # app build/check/signing only
├─ docs/
└─ harness/                 # must not exist after R1
```

`services/brain` is an existing, documented service and moves in neither R3 nor
R4; it is listed so the tree is honest. `services/backend` is reserved (README +
ADR-0011, no package). `services/wire` is the shared library: the services
repository split moves all of `services/` together (ADR-0012).

## 2. Current state, measured 2026-11-12

| Fact | Value / correction |
|---|---|
| Harmony project root | `apps/harmony/` (`build-profile.json5`, `hvigorfile.ts`, `oh-package.json5`) |
| `core` purity | 0 `@kit.*` / `@ohos.*` imports under `core/src/main` |
| Python **distributions** | `hopa-pc-agent`, `hopa-agent`, `hopa-bench` |
| Python **console scripts** | `pc-agent`, `hopa-agent`, `bench` |
| Package dirs | `hopa_pc_agent/`, `hopa_agent/`, `hopa_bench/` |
| Bridge package contents | `bridge.py`, `bridge_pool.py`, `chat_store.py`, `cli.py`, `device.py`, `hdc.py`, `images.py`, `layout.py`, `mcp_server.py`, `relay.py`, `tunnel.py`, `ws.py`, `apps.py`, `errors.py`, `__init__.py`, `__main__.py` |
| Import graph (inner) | `bridge → chat_store, device`; `bridge_pool → bridge, chat_store, device, images`; `device → hdc, layout, errors`; `mcp_server → device, errors`; `relay → tunnel → ws`; `cli → device, layout, errors` |
| Direct hdc use from the API | `bridge.py` calls `device.hdc.shell` / `file_recv` (≈ lines 150, 153) — the seam in R6 must cover this |
| Relay is one deployable, two halves | `relay.py` (server: `Relay`, serve loop), `tunnel.py` (`TunnelRegistry` **and** PC-side `HdcTunnel`), `ws.py` (frame codec) |
| PC-only commands | `cloud-link` and `hdc-tunnel` (used by `run-agent.ps1`), so they stay on the PC |
| Relay deploy | `render.yaml`: `pip install --no-deps ./services/pc-agent`, `python -m hopa_pc_agent relay` |
| Stale root project | `app/` has **2 tracked files** (`code-linter.json5`, `entry/src/main/resources/.../color.json`), 0 `.ets`; `.idea/` is untracked/ignored |
| CI Python paths | `.github/workflows/ci.yml` install/ruff/pytest/validate lines |
| Scripts with paths | `run-tests.ps1`, `run-tests.sh`, `run-bench.ps1`, `run-bench.sh`, `run-agent.ps1`, `run-phone.ps1`, `run-laptop.ps1`, `bridges.ps1` |
| Docs carrying `harness` | 29 files under `docs/` plus `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md` (prose, not a path), `.github/PULL_REQUEST_TEMPLATE.md` |
| OpenAPI | none; 4 JSON schemas only |
| Root pytest config | none — `pytest services <evals>` collides on duplicate `test_cli.py` basenames |
| Baseline state at HEAD | `build-app-catalog.py --check` exits 1 (stale `AppCatalog.ets`); `pytest tools/scripts` 1 failed / 17 passed; repo-wide `ruff` red (defaults, not per-package config) |

## 3. Non-goals

- No change to bridge HTTP paths, auth, payloads, ChatSync rules, prompts or UI.
- No Android/Windows code; R9 creates folder READMEs only.
- No `services/backend` package, no runtime move (R7 is an ADR).
- No rewrite of `docs/project/archive/` or the retired rebuild plan (tag
`rebuild-plan-2026-11-13`).

---

## R0. Make HEAD green, reset the env, record decisions

Baseline first: every "CI green" box after a rename is meaningless if HEAD is red.

### R0.1 Baseline is green

- [x] Regenerate the app catalogue: `python tools/scripts/build-app-catalog.py` (evidence: commit a6bebae)
      then `--check` exits 0. (evidence: "35 apps and 21 sites are current")
- [x] Fix `pytest tools/scripts` (was failing on the stale catalogue). (evidence: commit a6bebae)
      (evidence: `pytest tools/scripts` -> 18 passed)
- [x] Add a root `pytest.ini` with `addopts = --import-mode=importlib` so (evidence: commit a6bebae)
      `pytest services evals` does not collide on the two `test_cli.py` files.
      (evidence: `pytest services harness tools/scripts` -> 380 passed)
- [x] Replace the repo-wide ruff gate with path-scoped commands; fix the four (evidence: commit a6bebae)
      `ruff check` errors and format `tools/` so the scoped gate is clean.
      (evidence: `ruff check services harness tools` -> All checks passed;
      `ruff format --check services harness tools` -> 159 files already formatted)
- [x] Record the green baseline in `docs/project/status.md` with the commands and (evidence: commit a6bebae)
      the commit. (evidence: "Refactor baseline (2026-11-12)" section)

### R0.2 Environment reset (stale editable installs)

- [x] `pip uninstall -y hopa-pc-agent hopa-agent hopa-bench`. (evidence: three
      "Successfully uninstalled" lines)
- [x] Delete stale console wrappers and metadata from the global site-packages (evidence: commit a6bebae)
      (the uninstall removes them; verified by the reinstall below).
- [x] Reinstall from paths and prove the three CLIs run against the current tree. (evidence: commit a6bebae)
      (evidence: `python -m hopa_pc_agent --help`, `-m hopa_agent --help`,
      `-m hopa_bench --help` all print their usage)
- [x] Do not rely on alias proofs before this reset. (evidence: recorded here)

### R0.3 Decisions (write them, then move)

- [x] ADR `docs/design/decisions/0007-top-level-taxonomy.md` written and indexed. (evidence: commit a6bebae)
      (evidence: docs/design/decisions/README.md table row 0007)
- [x] ADR `docs/design/decisions/0008-python-distribution-renames.md` written and indexed. (evidence: commit a6bebae)
      (evidence: docs/design/decisions/README.md table row 0008)
- [x] ADR `docs/design/decisions/0009-relay-is-a-server-half.md` written and indexed. (evidence: commit a6bebae)
      (evidence: docs/design/decisions/README.md table row 0009)
- [x] `docs/design/architecture/layers.md`: top-level routing table, "agent is a product (evidence: commit a6bebae)
      word", and the second-level table kept. (evidence: layers.md "Where does a
      new thing go?" section)

Verification: `check-links.py` green; `plan-status --plan docs/plan --lint`
green. Risk: none (docs + regenerate). Rollback: revert the R0 commit.

---

## R1. `harness/` → `evals/`, and `hopa_agent` → `hopa_baseline`

One atomic commit: move + imports + pyproject + CI + scripts + docs.

### R1.1 Move and rename

- [x] `git mv harness evals`. (evidence: `harness/` no longer exists)
- [x] `git mv evals/agent evals/baseline`. (evidence: commit 8ab86a2)
- [x] `git mv evals/baseline/src/hopa_agent evals/baseline/src/hopa_baseline`. (evidence: commit 8ab86a2)
- [x] Rewrite imports in `evals/baseline/**` (src + tests + conftest). (evidence: commit 8ab86a2)
      (evidence: `pytest evals` -> 223 passed)
- [x] `evals/baseline/pyproject.toml`: name `hopa-baseline`, description updated, (evidence: commit 8ab86a2)
      scripts `hopa-baseline` + one-release `hopa-agent`, first-party
      `hopa_baseline`. (evidence: file, lines 6-8 and 20-24)
- [x] `evals/bench/pyproject.toml`: first-party list verified (it named (evidence: commit 8ab86a2)
      `hopa_bench`/`hopa_pc_agent`, no change needed).
- [x] CI coverage flag `--cov=hopa_baseline`; step renamed "pytest (baseline)". (evidence: commit 8ab86a2)
      (evidence: .github/workflows/ci.yml)
- [x] `evals/bench/tasks` needed no prose edit: 0 occurrences of "agent" there. (evidence: commit 8ab86a2)

### R1.2 References (complete list, verified by critique)

- [x] `.github/workflows/ci.yml`: install paths, ruff targets, pytest targets, (evidence: commit 8ab86a2)
      `validate --tasks evals/bench/tasks`, coverage flag.
- [x] `.github/dependabot.yml`: `/evals/baseline`, `/evals/bench`. (evidence: commit 8ab86a2)
- [x] `tools/scripts/run-tests.ps1` and `run-tests.sh`. (evidence: commit 8ab86a2)
- [x] `tools/scripts/run-bench.ps1` and `run-bench.sh` (results, install, tasks). (evidence: commit 8ab86a2)
- [x] `.gitleaks.toml` allowlist -> `evals/baseline/tests/.*`, (evidence: commit 8ab86a2)
      `evals/bench/tasks/.*`.
- [x] `.gitignore`: dead `bench/results|artifacts` replaced with (evidence: commit 8ab86a2)
      `evals/bench/results|artifacts`; the six committed result JSONs stay
      deliberately (noted here, not ignored).
- [x] `README.md` (all five sites), `CLAUDE.md`, `CONTRIBUTING.md`, (evidence: commit 8ab86a2)
      `.github/PULL_REQUEST_TEMPLATE.md`.
- [x] `SECURITY.md` prose noun. (evidence: commit 8ab86a2)
- [x] `docs/design/decisions/0001-brain-hosting.md`, `0005-pc-tethered-vs-standalone.md`. (evidence: commit 8ab86a2)
- [x] `docs/design/architecture/{overview,target-structure}.md` (+ ?5 paths). (evidence: commit 8ab86a2)
- [x] `docs/reference/contracts/{action,observation}.md`, (evidence: commit 8ab86a2)
      `docs/reference/{abuse,safety,threat-model,bundles,brain}.md`,
      `docs/guides/harmony/{setup,device-testing}.md`,
      `docs/design/product/{roadmap,bench,bench-results-v0,coverage}.md`,
      `docs/project/operations/{owners,acl-request,sbom.json}`,
      `docs/project/status.md`.
- [x] `docs/project/plan/README.md` and `appendix-a`, `appendix-e`; `phase-*.md` (evidence: commit 8ab86a2)
      restored untouched (frozen evidence).
- [x] `docs/project/archive/`: frozen; one pointer note appended to `port-log.md`. (evidence: commit 8ab86a2)

### R1.3 Gates

- [x] `rg -n "hopa_agent"` -> 26 hits, all in the retired rebuild plan (tag (evidence: commit 8ab86a2)
      `rebuild-plan-2026-11-13`) and this plan itself. (evidence: grep grouped by file)
- [x] `rg -n "harness"` -> only frozen docs, the plan, one explanatory note in (evidence: commit 8ab86a2)
      `docs/project/status.md`, and one ArkTS test identifier (`const harness`).
- [x] Fresh install and proof: `hopa-baseline --help`, `hopa-agent --help` (evidence: commit 8ab86a2)
      (alias), `bench --help`. (evidence: reinstall output + help output)
- [x] `pytest evals` 223 passed; `ruff check evals` clean; `ruff format --check (evidence: commit 8ab86a2)
      evals` 52 files formatted. (evidence: commands)
- [x] `python -m hopa_bench validate --tasks evals/bench/tasks` -> 20 valid. (evidence: commit 8ab86a2)
- [x] `check-structure.py --strict` 0 violations; `check-links.py` 0 broken; (evidence: commit 8ab86a2)
      `plan-status.py --lint` and `--plan docs/plan --lint` pass;
      `build-app-catalog.py --check` current; `pytest tools/scripts` 18 passed.
- [x] CI green on the new paths. (evidence: PR #29, run 43330497581)
- [x] Evidence: PR #29, run 43330497581 (all jobs green; macOS Local Test skipped). (evidence: commit 8ab86a2)

Risk: medium (many references). Rollback: revert the single atomic commit;
then `pip uninstall` the new distributions and reinstall (pip does not remove the
old `*.dist-info` on a rename).

---

## R2. Delete the stale root `app/`

- [x] Prove nothing references it: the only `app[\\/](entry|build|code-linter)` (evidence: commit 2b46cbe)
      match is the `$app` variable in `tools/scripts/install-to-device.sh`.
- [x] `tools/scripts/build.ps1` is the gate, and it is green after the deletion: (evidence: commit 2b46cbe)
      `BUILD SUCCESSFUL in 2 min 574 ms`. (evidence: build output)
- [x] `git rm -r -- app` removed the 2 tracked files and `git clean -fdx -- app` (evidence: commit 2b46cbe)
      removed the ignored `.idea/`; `Test-Path app` -> `False`.
- [x] No `.gitignore` entry existed solely for it (all app patterns are `**/...`). (evidence: commit 2b46cbe)
- [x] `README.md` tree has no root `app/`. (evidence: commit 2b46cbe)
- [x] CI green for the deletion. (evidence: PR #29, run 43330497581)

Risk: low. Detector: the HAP build fails immediately if anything depended on it.

## R3. `services/pc-agent` -> `services/bridge`, package `hopa_bridge`

One atomic commit (move + imports + pyproject + CI + scripts + docs).
Decision (ADR-0008): **the command stays `pc-agent`**; `hopa-bridge` is the alias.

### R3.1 Move and rename

- [x] `git mv services/pc-agent services/bridge` (`services/pc-agent` no longer (evidence: commit 097d2df)
      exists).
- [x] `git mv services/bridge/src/hopa_pc_agent services/bridge/src/hopa_bridge`. (evidence: commit 097d2df)
- [x] Imports rewritten in `services/bridge/**` **and** `evals/**`. (evidence: commit 097d2df)
      (evidence: `pytest services/bridge evals` -> 362 passed)
- [x] `services/bridge/pyproject.toml`: `name = "hopa-bridge"`, scripts (evidence: commit 097d2df)
      `hopa-bridge` + `pc-agent` alias, first-party `hopa_bridge`.
- [x] `mcp_server.py` `SERVER_NAME` -> `hopa-bridge`; `tests/test_mcp.py` asserts (evidence: commit 097d2df)
      the new literal. `cli.py` keeps `prog="pc-agent"` (the command name).
- [x] `render.yaml`: install `./services/bridge`, run `python -m hopa_bridge relay` (evidence: commit 097d2df)
      (the relay stays here until R4).
- [x] Cross-distribution note: bench/baseline import `hopa_bridge` without a (evidence: commit 097d2df)
      declared dependency; the install-order line is in each README.
- [x] `services/bridge/README.md`: title and install line follow the name. (evidence: commit 097d2df)

### R3.2 References

- [x] All scripts: `run-agent.ps1`, `run-phone.ps1`, `run-laptop.ps1`, (evidence: commit 097d2df)
      `bridges.ps1`, `run-bench.ps1|sh`, `run-tests.ps1|sh` - install paths and
      `-m hopa_bridge`.
- [x] `.github/workflows/ci.yml` (job "bridge + evals", step "pytest (bridge)"), (evidence: commit 097d2df)
      `.github/dependabot.yml`.
- [x] `README.md`, `CLAUDE.md`, `CONTINUE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, (evidence: commit 097d2df)
      `.github/PULL_REQUEST_TEMPLATE.md`, `.env.example`.
- [x] `docs/project/operations/sbom.json`, `owners.md`. (evidence: commit 097d2df)
- [x] `docs/design/architecture/{data-flow,overview,target-structure}.md`, (evidence: commit 097d2df)
      `docs/guides/harmony/{setup,pc-bridge}.md`, `docs/reference/*`,
      `docs/design/product/*`, `docs/project/plan/README.md`.
- [x] `tools/scripts/ui-smoke.py`, `repair-chats.py` strings. (evidence: commit 097d2df)
- [x] `apps/harmony/phone/.../BridgeWizard.ets` prints `-m hopa_bridge`. (evidence: commit 097d2df)
- [x] `docs/project/archive/*` and the retired rebuild plan untouched (frozen at the (evidence: commit 097d2df)
      tag).

### R3.3 Gates

- [x] `rg -n "hopa_pc_agent"` -> 0 outside frozen docs and this plan. (evidence: commit 097d2df)
- [x] `pytest services/bridge` + `pytest evals` -> 362 passed; `ruff check` (evidence: commit 097d2df)
      clean; 20 bench tasks valid.
- [x] `python -m hopa_bridge --help` works; `pc-agent --help` works (alias). (evidence: commit 097d2df)
- [x] Device smoke on both devices: `devices` lists both serials, `screenshot` (evidence: commit 097d2df)
      saved for the laptop, `dump` parsed the laptop's Settings screen, `apps`
      listed 2-in-1 bundles. (evidence: bridge-shot.png, bridge-layout.json)
- [x] Bridge smoke + laptop `Connected.`: Settings -> Bridge reads `Connected.` (evidence: commit 097d2df)
      and the footer reads `Bridge connected - every action asks first.`
      (evidence: device screenshot e2e14)
- [x] Cross-device E2E on the installed builds: from the laptop, target `Phone`, (evidence: commit 097d2df)
      ask "open douyin and tell me what you see"; Douyin opens on the phone
      (minor-mode sheet visible), the answer returns in the laptop chat, and the
      run pane reads `Succeeded, 1 step, 3.7 s`. (evidence: x2/x3 screenshots)
- [ ] [DEFERRED: no deploy access] Relay smoke against the Render preview.
- [x] CI green; PR #29, run 43330497581. (evidence: commit 097d2df)

Risk: medium-high. Rollback: revert the atomic commit, `pip uninstall hopa-bridge`,
reinstall, and revert `render.yaml` + redeploy if the relay line moved.

## R4. Split the relay **server half** into `services/relay`

Goal: the relay host installs only relay code; a PC still keeps `cloud-link` and
`hdc-tunnel`, so a PC never needs the relay package.

### R4a. The shared wire package

- [x] `services/wire` (ADR-0010): `ws.py` moved, tunnel frames and `TunnelSide`. (evidence: commit d896d8d)
- [x] `check-tree.py` allows the shared package and the docs name it; it was (evidence: commit d896d8d)
      later moved from `packages/wire` to `services/wire` so the services
      repository split takes it along (ADR-0012).
- [x] CI and run scripts install the wire package first. (evidence: commit d896d8d)
- [x] Evidence: commit 732d83b; `pytest services/bridge services/wire` 139 passed. (evidence: commit d896d8d)

### R4b. The two halves

- [x] `services/relay/src/hopa_relay/`: `relay_server.py` (Relay, RelayServer, (evidence: commit d896d8d)
  serve_relay), `registry.py` (TunnelRegistry), `cli.py` (`hopa-relay relay`).
- [x] `services/bridge/src/hopa_bridge/cloud_link.py`: `LinkClient`, `serve_link` (evidence: commit d896d8d)
  (the PC half), importing `hopa_wire.errors`.
- [x] `services/bridge/src/hopa_bridge/tunnel.py` keeps `HdcTunnel` and (evidence: commit d896d8d)
  `serve_hdc_tunnel`; `TunnelRegistry` moved to the relay package.
- [x] Shared relay errors moved to `hopa_wire.errors` so the PC half never imports (evidence: commit d896d8d)
  the relay package.
- [x] Bridge CLI: `relay` prints "moved to hopa-relay" and exits 2; `cloud-link` (evidence: commit d896d8d)
  and `hdc-tunnel` stay and still work.
- [x] Tests split: relay suite in `services/relay/tests`, the tunnel/CLI tests in (evidence: commit d896d8d)
  the bridge. The two `LinkClient` end-to-end tests import the relay test fixture;
  that is test-only coupling, the runtime direction stays bridge -> wire.
- [x] `render.yaml`: build `./services/wire ./services/relay`, start (evidence: commit d896d8d)
  `python -m hopa_relay relay`. CI installs, lints and tests the relay package.

### R4c. Gates

- [x] `pytest services/relay services/bridge services/wire` -> 139 passed. (evidence: commit d896d8d)
- [x] Clean-venv proof of the deploy command: `pip install --no-deps (evidence: commit d896d8d)
      ./services/wire ./services/relay`, then `python -m hopa_relay relay` and
      `/health` returns `role: relay`. (evidence: port 8792 run)
- [x] Local relay: `python -m hopa_relay relay --host 127.0.0.1 --port 8791` and (evidence: commit d896d8d)
  `GET /health` -> `{"ok": true, "role": "relay", ...}`.
- [x] `hopa_bridge relay` prints the deprecation and exits 2. (evidence: commit d896d8d)
- [x] `check-tree` 0 violations, `check-links` 0 broken, ruff clean. (evidence: commit d896d8d)
- [ ] [DEFERRED: no deploy access] Render preview healthy. Owner: whoever holds
  the Render account; the exact commands are in `render.yaml`.
- [x] CI green on the split. (evidence: PR #29, run 43330497581)

Risk: medium (one production blueprint line). Rollback: revert the relay commit,
then the render commit, then redeploy; `pip uninstall hopa-relay`.

## R5. Freeze the bridge API in `contracts/` (against the real files)

No runtime change. Written against `bridge.py` + `bridge_pool.py`, since the
`api/` split does not exist yet.

- [x] `contracts/openapi/bridge.v1.yaml` covers the real surface, 21 paths: (evidence: commit 3a96245)
      `/health`, `/whoami`, `/pair`, `/refresh`, `/observe`, `/tap`, `/type`,
      `/swipe`, `/screenshot`, `/launch`, `/foreground`, `/stop`, `/focus`,
      `/key`, `/voices`, `/images`, `/images/{id}`, `GET|POST /chats`,
      `GET|POST /sessions`, `/transcribe`, `/speak`. (evidence: checker reports
      "ok 21 spec path(s), 20 code route(s), 1 prefix route(s)")
- [x] Auth is in the spec: bearer token, bootstrap vs paired token, the 12-hour (evidence: commit 3a96245)
      lifetime, `X-Hopa-Role` routing, `X-Hopa-Read`, error body.
- [x] `contracts/openapi/README.md`: same-PR rule, both-directions check, prefix (evidence: commit 3a96245)
      routes, versioning.
- [x] `tools/checks/check-openapi.py` reads the `self.path ==` chain in (evidence: commit 3a96245)
      `bridge.py` + `bridge_pool.py`, allows declared prefixes, fails both ways;
      unit tests in `tools/scripts/test_check_openapi.py` (5 tests).
- [x] `docs/reference/protocols.md` indexes bridge HTTP, relay, brain, MCP and the (evidence: commit 3a96245)
      four schemas; the `protocols` row in `docs/README.md` now points at it.
- [x] CI step "Bridge contract"; `check-links.py` and `pytest tools/scripts` (evidence: commit 3a96245)
      green. (evidence: `pytest tools/scripts` -> 23 passed)

Risk: low. Deferred decision: `/v1` prefix (recorded; not done here).

## R6. A device seam in the bridge - protocol only, no folder split

`device.py` cannot become `device/` while the module exists (Windows is
case-insensitive), so the seam is added in flat files; the folder split can come
later without changing the API.

- [x] `services/bridge/src/hopa_bridge/device_port.py`: `DevicePort` Protocol with (evidence: commit a3f9aa5)
      `dump_layout`, `foreground`, `tap`, `swipe`, `type_text`, `press_key`,
      `press_key_many`, `launch`, `stop`, `shell`, `pull`, `serial`, `platform`.
- [x] `device_harmony.py`: `HarmonyDevice` wraps today's `Device` and owns the two (evidence: commit a3f9aa5)
      direct hdc calls (`shell`, `file_recv`) that `bridge.py` used to make.
- [x] `bridge.py` imports `DevicePort`, never `Device` or `hdc`; the screenshot (evidence: commit a3f9aa5)
      path calls `device.shell` / `device.pull`.
- [x] `bridge_pool.py` wraps whatever the factory returns in `HarmonyDevice` and (evidence: commit a3f9aa5)
      reports `platform` in `/health`.
- [x] `cli.py` wraps at the composition root; bridge and CLI behaviour unchanged. (evidence: commit a3f9aa5)
- [x] `check-structure.py` gains a Python rule: only `hdc.py`, `device.py` and (evidence: commit a3f9aa5)
      `device_harmony.py` may import `hdc`.
- [x] Tests: the fake device implements the port; `services/bridge services/relay (evidence: commit a3f9aa5)
      services/wire` -> 139 passed.
- [x] Hardware: `devices` lists both serials, one screenshot saved, one `dump` (evidence: commit a3f9aa5)
      parsed on the 2-in-1.
- [x] `docs/guides/harmony/adding-a-platform.md` names the real files and the shell/pull (evidence: commit a3f9aa5)
      methods.

Risk: medium (signature change inside the bridge). Rollback: revert the single
commit; no data changes.

## R7. Record the backend boundary (ADR + runbook, no package)

- [x] ADR-0011: the loop is a server concern; today it stays on the device until (evidence: commit 0aa431c)
  services/backend exists; clients are thin; the bridge stays the device plane;
  shared code is versioned, not copied.
- [x] Assignment decided (2026-11-13): evals/, the service half of tools/ and the (evidence: commit 0aa431c)
  service docs move with services/; contracts/ is shared by version.
- [x] docs/project/operations/repo-split.md: target repositories, preconditions, order (evidence: commit 0aa431c)
  (backend, wire, bridge/relay, apps), git filter-repo mechanics, per-repo CI
  and the rollback tag.
- [x] ADR-0011 is in the index; no services/backend package, no CI job, no (evidence: commit 0aa431c)
  runtime stub (the ADR explains why a stub would be worse than nothing).

Risk: none. Rollback: revert the docs commit.

## R8. Rules, docs, and the checks that keep the tree honest

- [x] `tools/checks/check-tree.py`: directory names only; skips dot-directories (evidence: commit 43b308f)
      and build/vendor output; allow-lists the top level; fails on `harness/` and
      on `utils|helpers|common|misc|shared` at any depth.
      (evidence: `0 tree violation(s)`)
- [x] `tools/scripts/test_check_tree.py`: five tests - the real repo, an unknown (evidence: commit 43b308f)
      top-level folder, `harness/`, a nested junk drawer, and ignored build/dot
      directories. (evidence: 5 passed)
- [x] `check-links.py` extended to `contracts/**` and to `README.md` under (evidence: commit 43b308f)
      `apps/`, `services/`, `evals/`, `tools/`. It immediately found a stale
      `../docs/brain.md` in `services/brain/README.md`, now
      `../../docs/reference/brain.md`.
- [x] `README.md` repository map includes `contracts/` and `tools/`; (evidence: commit 43b308f)
      `CONTRIBUTING.md` gained the "where does a new file go?" table (top level
      then layer, with the two absolute rules); `CLAUDE.md` paths refreshed in
      R1/R3; `docs/project/plan/README.md` links this plan without adding boxes to the
      M-plan. (evidence: links 0 broken)
- [x] `docs/design/architecture/layers.md` routes by top level (R0); `overview.md` and (evidence: commit 43b308f)
      `data-flow.md` follow the new paths (R1/R3).
- [x] CI step "Tree rules"; gates green: `check-tree`, `check-structure (evidence: commit 43b308f)
      --strict`, `check-links`, `plan-status --lint`, `pytest tools/scripts`.

Risk: low.

## R9. Reserve the platform folders (README only)

- [x] `apps/android/README.md`: Compose client that runs its own loop (ADR-0016), (evidence: commit 946e639)
      with two `DevicePort` adapters — bridge/adb and `AccessibilityService` (ADR-0017);
      behaviour shared through `contracts/` and fixtures.
- [x] `apps/windows/README.md`: WinUI shell, UI Automation adapter, the sparse-tree (evidence: commit 946e639)
      rule, contract-only traffic.
- [x] `docs/guides/harmony/adding-a-platform.md`: the `DevicePort` method table, the four (evidence: commit 946e639)
      honesty rules, and the checklist (adapter, registry platform value, fake
      adapter tests, hardware evidence, contract note).
- [x] Gate: `check-links.py` 0 broken (it now covers `apps/**/README.md` from R8) (evidence: commit 946e639)
      and `check-tree.py` accepts the two new folders.

Risk: none.

## R10. Fixes and cleanups after the E2E

- [x] The send arrow comes from an SVG asset, not `Path`: `Path` draws at its (evidence: commit 5561191)
      command extent and ignores width/height, so two size edits changed nothing.
      (evidence: fdcc67b, 02284a4)
- [x] One-release aliases retired: `services/bridge` exposes only `hopa-bridge`, (evidence: commit 5561191)
      `evals/baseline` only `hopa-baseline`; the CLI `prog` and error prefixes say
      hopa-bridge; the run scripts resolve `hopa-bridge.exe`; live docs, README,
      PR template and `ui-smoke` follow. Frozen history and ADR-0008 keep the old
      names on purpose. (evidence: `hopa-bridge --version`, `hopa-relay --help`,
      `hopa-baseline --version`; 362 tests)
- [x] Cross-distribution dependencies declared: `evals/bench` and `evals/baseline` (evidence: commit 5561191)
      depend on `hopa-bridge`; bridge and relay depend on `hopa-wire`; the install
      order is in each README and in CI. (evidence: pyproject files)
- [x] The resume theory corrected: `resumeInterrupted` has no callers, and the run (evidence: commit 5561191)
      pane showed the Douyin action under the new turn, so that was the model
      repeating a previous action on a nonsense prompt, not a resume bug. No code
      change was made on a false premise.
- [x] Dead `resumeInterrupted` removed from `LaptopIndex` (no callers), with the (evidence: commit 5561191)
      unused `preferences` import; HAP build green afterwards. (evidence: commit
      596b2b9, build `BUILD SUCCESSFUL`)
- [ ] Follow-up (product, not this refactor): a prompt/eval task so a nonsense
      prompt does not repeat the previous action. Recorded in
      `docs/project/status.md`; it needs the model/prompt work, not a structural
      change.

Risk: low. Rollback: revert the rename commit and reinstall the aliases.

## R13. Consolidate everything service-related under `services/`

Owner decision: the future split must be one path, so service code does not stay
behind in the app repository.

- [x] `evals/` -> `services/evals/` (bench, baseline); CIs, scripts, pyprojects, (evidence: commit 42bd681)
      docs and tests follow. (evidence: commit 42bd681, 395 tests)
- [x] Service tools -> `services/tools/`: bridges, run-agent, run-bench, (evidence: commit 42bd681)
      run-on-device, port-watch, repair-chats, and the openapi/render checkers.
      `tools/` keeps app build/install/catalog/plan/signing and its checks.
      (evidence: commit 42bd681, `tools/` now holds app tools only)
- [x] Scripts that moved one level deeper compute the repo root correctly; the (evidence: commit 42bd681)
      app scripts they call are referenced through `$root`. (evidence: the
      `Split-Path` depth and `$root` references in services/tools/scripts/*.ps1)
- [x] `run-tests.ps1` argument list repaired (a `Join-Path` array slipped in (evidence: commit 42bd681)
      during the move). (evidence: the pip/pytest argument lines now use one
      `Join-Path` per path)
- [x] Relative paths in tests fixed for the new depth (`contracts/schemas`, (evidence: commit 42bd681)
      checker `ROOT`). (evidence: 395 tests pass after the move)
- [x] ADR-0013 records the rule; ADR-0007 is marked superseded in part; (evidence: commit 42bd681)
      `check-tree.py` rejects a returning top-level `evals/`. (evidence:
      `check-tree.py` -> 0 violations)
- [x] Service docs moved to `services/docs/` (evidence: bb10cff, a295958) -
      guides, protocols, brain, knowledge, skills, bench, repo-split, ADR
      0009/0010/0012/0013; shared docs stay in `docs/`; both indexes rewritten and
      links repaired.
- [x] `pytest services/evals services/bridge services/relay services/wire` -> (evidence: commit 42bd681)
      362 passed (evidence: local run after the docs move); ruff clean; tree,
      links, both contracts, render and plan lint green.

Risk: low (moves and path fixes only). Rollback: revert the consolidation commit.

## Acceptance gates

| Gate | Command | Applies after |
|---|---|---|
| Python suites | per package, as CI does: `pytest services/bridge`, `pytest evals/bench`, `pytest evals/baseline`; plus `pytest services evals` once R0 adds `--import-mode=importlib` | R0 |
| Lint (scoped) | `ruff check services evals tools` / `ruff format --check …` | R0 |
| Structure | `python tools/checks/check-structure.py --strict` | every phase |
| Tree | `python tools/checks/check-tree.py` | R8+ |
| Contracts | `python tools/checks/check-openapi.py` | R5+ |
| Links | `python tools/checks/check-links.py` (extended in R8) | every phase |
| Plan | `python tools/scripts/plan-status.py --plan docs/project/plan --lint` | every phase |
| Catalogue | `python tools/scripts/build-app-catalog.py --check` | every phase |
| Build | `tools/scripts/build.ps1` | R2, R3 |
| Device | laptop app `Connected.` + one observe/tap | R3, R6 |
| Relay | `/health` on preview and on the PC half's `hdc-tunnel` | R4 |

## R15. Share the data every client reads

Scope added after the refactor, requested before Android development starts. The
loop stays per client (ADR-0016); the data and the cases move to `contracts/`
(ADR-0018).

- [x] `contracts/catalog/catalog.v1.json` is generated from `services/brain/knowledge`
      with a `platforms` map; the ArkTS copy is rendered from it and a Kotlin
      renderer exists. (evidence: `build-app-catalog.py --check`, 35 apps + 21 sites)
- [x] Approval vocabularies live in `contracts/policy/approval.v1.json`; the
      ArkTS gate reads generated data and keeps its logic. (evidence: 110 ArkTS
      tests pass, `build-policy-data.py --check`)
- [x] Prompt promises are `contracts/prompts/rules.v1.json`; a generated constant
      and `PromptContract.test.ets` assert every phrase. (evidence:
      `build-prompt-rules.py --check`, 12 rules)
- [x] Routing cases and an observation hash vector are fixtures with checkers.
      (evidence: `check-routing.py` and `check-observation-hash.py`, 0 problems)
- [x] CI and `tools/scripts/run-tests.ps1` run the new generators and checkers.
      (evidence: `.github/workflows/ci.yml`, `run-tests.ps1`)
- [x] ADR-0018 and `docs/reference/shared-data.md` explain the split.
      (evidence: 0 broken links)
- [x] Harmony regression on hardware: both HAPs built, installed, one live model
      turn each. (evidence: `docs/project/evidence/A0-shared-data-prep.md`)

## Rollback model

Each rename is **one** atomic commit (move + imports + pyproject + CI), so the
rollback is `git revert <sha>` followed by `pip uninstall` of the new
distributions and a reinstall — pip keeps the old `*.dist-info` and console
wrappers otherwise. R4 adds a second commit for `render.yaml`; revert that first,
then the package commit, then redeploy. R6 and R7 are single commits with no data
migration.

## Open decisions

- [x] CLI naming (one of the two must be checked) (evidence: ADR-0008)
      - [x] `pc-agent` primary, `hopa-bridge` alias. (evidence: ADR-0008)
      - [ ] `hopa-bridge` primary, `pc-agent` alias for one release.
- [x] Relay timing (one of the two must be checked) (evidence: ADR-0009)
      - [x] R4 separate, after R3. (evidence: ADR-0009)
      - [ ] R4 folded into R3.
- [x] `apps/harmony/app` naming (one of the two must be checked) (evidence: R0 decision)
      - [x] keep `app/`. (evidence: R0 decision, least churn)
      - [ ] rename to `shell/`.
- [x] `/v1` path prefix (one of the two must be checked) (evidence: R0 decision)
      - [x] after the backend exists. (evidence: R0 decision)
      - [ ] now, inside R5.

## 9. Critique log

A read-only sub-agent reviewed the first draft and verified it against the repo.
Accepted corrections, all folded into the text above:

1. ADR numbers 0006+ were taken; this plan now starts at 0007.
2. R5/R6 were written against a folder layout that does not exist; both now target
   the real flat files, and R6 no longer merges three modules.
3. The endpoint list was wrong (`/apps`, `/mcp` invented; `/key`, `/stop`,
   `/focus`, `/voices`, `/images`, `/d/<serial>/` missing); corrected.
4. R4's "clean cut" was false — `tunnel.py` holds both halves and `cloud-link` is
   a PC command; the phase now moves the server half only.
5. `rg → 0` gates were impossible because of frozen evidence; exclusions are now
   explicit.
6. Missing references added: `run-tests.sh`, `run-bench.sh`, `run-bench.ps1`,
   `known-first-party`, `.gitleaks.toml`, `.gitignore` dead entries, ADRs 0001/0005,
   plan appendices, `sbom.json`, `CHANGELOG.md`, `CONTINUE.md`, `.env.example`,
   `BridgeWizard.ets`, `mcp_server.py`, `cli.py`, `CODEOWNERS`, five `README.md`
   sites, `docs/README.md`.
7. The "move commit is green" claim was impossible; each rename is now one atomic
   commit and the rollback model was rewritten.
8. HEAD was red; R0 now makes it green (catalogue, `pytest tools/scripts`, scoped
   ruff, root pytest `--import-mode=importlib`) before any move.
9. Stale editable installs could fake the alias proof; R0.2 resets them.
10. `git rm -r app` left the folder; now `git rm -r --` + `git clean -fd`.
11. R7 (backend skeleton) was over-engineered; it is now an ADR only.
12. `check-tree.py` was over-scoped; it now looks at directory names only and
    skips dot-directories.
13. Decision-pair markers and conditional-box lint rules are now satisfied.

Rejected/deferred: none. The critique's "split R6 into two plans" is honoured by
scoping R6 to the protocol only.
