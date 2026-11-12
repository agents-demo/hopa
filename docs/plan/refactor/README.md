# Refactor plan: apps, services, evals

Status: **revised after critique; execution starts at R0.**
Written 2026-11-12; revised same day (critique pass recorded in §9).
Scope: structure and naming only. No behaviour change, no new platform code.

Three futures this prepares for:

1. **Android HOPA** and **Windows HOPA** as additional `apps/`.
2. The **bridge as a real backend** (device plane + relay), later a separate repo.
3. **evals/** as the place quality is measured, instead of `harness/`.

Kept out of `docs/plan/*.md` on purpose: `tools/scripts/plan-status.py` globs
that folder non-recursively, so this work does not enter the M-milestone gate.
Count it with:

```bash
python tools/scripts/plan-status.py --plan docs/plan/refactor
python tools/scripts/plan-status.py --plan docs/plan/refactor --lint
```

## 0. Rules

- Every `[x]` carries `(evidence: ...)` on the same line: command output, CI run
  id, PR number, or device screenshot. No evidence, no tick.
- One phase = one mergeable change. **Each rename is one atomic commit**: the
  move, the imports, the pyproject edit and the CI paths land together, because
  CI installs by path and a "move only" commit cannot be green.
- `git mv` for tracked files, so blame survives. Caches and `.idea` are untracked
  and are cleaned, not moved.
- New paths exist before old ones only where a transition needs both (console
  script aliases). Everywhere else the old path is gone in the same commit.
- `docs/history/` and ticked `docs/plan/phase-*` evidence are **frozen**. They may
  keep old paths; everything else must not.
- **`agent` is a product word.** Evaluation code is a *baseline* or a *driver*.
- No junk drawers: `utils/`, `helpers/`, `common/`, `misc/`, `shared/`.
- `docs/architecture/layers.md` remains the authority for import direction.
- Decision boxes come in pairs with the literal marker
  `(one of the two must be checked)`; conditional work is prose.

## 1. Target tree

```
hopa/
├─ apps/                    # what a person holds
│  ├─ harmony/              # DevEco workspace (exists)
│  ├─ android/              # README first (R9)
│  └─ windows/              # README first (R9)
├─ services/                # what runs with nobody watching
│  ├─ bridge/               # device plane (R3)
│  ├─ relay/                # cloud relay server half (R4)
│  ├─ brain/                # Kotlin knowledge router (exists, unchanged)
│  └─ backend/              # planned; only an ADR in R7, no package yet
├─ evals/                   # how we know it got better (R1)
│  ├─ bench/
│  └─ baseline/
├─ contracts/
│  ├─ openapi/              # bridge.v1.yaml (R5)
│  └─ schemas/              # 4 JSON schemas (exists)
├─ tools/                   # scripts/, checks/, signing/
├─ docs/
└─ harness/                 # must not exist after R1
```

`services/brain` is an existing, documented service and moves in neither R3 nor
R4; it is listed so the tree is honest. `services/backend` is deliberately **not**
created in this plan (R7 records the boundary in an ADR only).

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
- No rewrite of `docs/history/` or ticked evidence in `docs/plan/phase-*`.

---

## R0. Make HEAD green, reset the env, record decisions

Baseline first: every "CI green" box after a rename is meaningless if HEAD is red.

### R0.1 Baseline is green

- [x] Regenerate the app catalogue: `python tools/scripts/build-app-catalog.py`
      then `--check` exits 0. (evidence: "35 apps and 21 sites are current")
- [x] Fix `pytest tools/scripts` (was failing on the stale catalogue).
      (evidence: `pytest tools/scripts` -> 18 passed)
- [x] Add a root `pytest.ini` with `addopts = --import-mode=importlib` so
      `pytest services evals` does not collide on the two `test_cli.py` files.
      (evidence: `pytest services harness tools/scripts` -> 380 passed)
- [x] Replace the repo-wide ruff gate with path-scoped commands; fix the four
      `ruff check` errors and format `tools/` so the scoped gate is clean.
      (evidence: `ruff check services harness tools` -> All checks passed;
      `ruff format --check services harness tools` -> 159 files already formatted)
- [x] Record the green baseline in `docs/status/backlog.md` with the commands and
      the commit. (evidence: "Refactor baseline (2026-11-12)" section)

### R0.2 Environment reset (stale editable installs)

- [x] `pip uninstall -y hopa-pc-agent hopa-agent hopa-bench`. (evidence: three
      "Successfully uninstalled" lines)
- [x] Delete stale console wrappers and metadata from the global site-packages
      (the uninstall removes them; verified by the reinstall below).
- [x] Reinstall from paths and prove the three CLIs run against the current tree.
      (evidence: `python -m hopa_pc_agent --help`, `-m hopa_agent --help`,
      `-m hopa_bench --help` all print their usage)
- [x] Do not rely on alias proofs before this reset. (evidence: recorded here)

### R0.3 Decisions (write them, then move)

- [x] ADR `docs/adr/0007-top-level-taxonomy.md` written and indexed.
      (evidence: docs/adr/README.md table row 0007)
- [x] ADR `docs/adr/0008-python-distribution-renames.md` written and indexed.
      (evidence: docs/adr/README.md table row 0008)
- [x] ADR `docs/adr/0009-relay-is-a-server-half.md` written and indexed.
      (evidence: docs/adr/README.md table row 0009)
- [x] `docs/architecture/layers.md`: top-level routing table, "agent is a product
      word", and the second-level table kept. (evidence: layers.md "Where does a
      new thing go?" section)

Verification: `check-links.py` green; `plan-status --plan docs/plan/refactor --lint`
green. Risk: none (docs + regenerate). Rollback: revert the R0 commit.

---

## R1. `harness/` → `evals/`, and `hopa_agent` → `hopa_baseline`

One atomic commit: move + imports + pyproject + CI + scripts + docs.

### R1.1 Move and rename

- [x] `git mv harness evals`. (evidence: `harness/` no longer exists)
- [x] `git mv evals/agent evals/baseline`.
- [x] `git mv evals/baseline/src/hopa_agent evals/baseline/src/hopa_baseline`.
- [x] Rewrite imports in `evals/baseline/**` (src + tests + conftest).
      (evidence: `pytest evals` -> 223 passed)
- [x] `evals/baseline/pyproject.toml`: name `hopa-baseline`, description updated,
      scripts `hopa-baseline` + one-release `hopa-agent`, first-party
      `hopa_baseline`. (evidence: file, lines 6-8 and 20-24)
- [x] `evals/bench/pyproject.toml`: first-party list verified (it named
      `hopa_bench`/`hopa_pc_agent`, no change needed).
- [x] CI coverage flag `--cov=hopa_baseline`; step renamed "pytest (baseline)".
      (evidence: .github/workflows/ci.yml)
- [x] `evals/bench/tasks` needed no prose edit: 0 occurrences of "agent" there.

### R1.2 References (complete list, verified by critique)

- [x] `.github/workflows/ci.yml`: install paths, ruff targets, pytest targets,
      `validate --tasks evals/bench/tasks`, coverage flag.
- [x] `.github/dependabot.yml`: `/evals/baseline`, `/evals/bench`.
- [x] `tools/scripts/run-tests.ps1` and `run-tests.sh`.
- [x] `tools/scripts/run-bench.ps1` and `run-bench.sh` (results, install, tasks).
- [x] `.gitleaks.toml` allowlist -> `evals/baseline/tests/.*`,
      `evals/bench/tasks/.*`.
- [x] `.gitignore`: dead `bench/results|artifacts` replaced with
      `evals/bench/results|artifacts`; the six committed result JSONs stay
      deliberately (noted here, not ignored).
- [x] `README.md` (all five sites), `CLAUDE.md`, `CONTRIBUTING.md`,
      `.github/PULL_REQUEST_TEMPLATE.md`.
- [x] `SECURITY.md` prose noun.
- [x] `docs/adr/0001-brain-hosting.md`, `0005-pc-tethered-vs-standalone.md`.
- [x] `docs/architecture/{overview,target-structure}.md` (+ ?5 paths).
- [x] `docs/contracts/{action,observation}.md`,
      `docs/reference/{abuse,safety,threat-model,bundles,brain}.md`,
      `docs/guides/{setup,device-testing}.md`,
      `docs/product/{roadmap,bench,bench-results-v0,coverage}.md`,
      `docs/operations/{owners,acl-request,sbom.json}`,
      `docs/status/backlog.md`.
- [x] `docs/plan/README.md` and `appendix-a`, `appendix-e`; `phase-*.md`
      restored untouched (frozen evidence).
- [x] `docs/history/`: frozen; one pointer note appended to `port-log.md`.

### R1.3 Gates

- [x] `rg -n "hopa_agent"` -> 26 hits, all in frozen `docs/plan/phase-*` and the
      plan itself. (evidence: grep grouped by file)
- [x] `rg -n "harness"` -> only frozen docs, the plan, one explanatory note in
      `docs/status/backlog.md`, and one ArkTS test identifier (`const harness`).
- [x] Fresh install and proof: `hopa-baseline --help`, `hopa-agent --help`
      (alias), `bench --help`. (evidence: reinstall output + help output)
- [x] `pytest evals` 223 passed; `ruff check evals` clean; `ruff format --check
      evals` 52 files formatted. (evidence: commands)
- [x] `python -m hopa_bench validate --tasks evals/bench/tasks` -> 20 valid.
- [x] `check-structure.py --strict` 0 violations; `check-links.py` 0 broken;
      `plan-status.py --lint` and `--plan docs/plan/refactor --lint` pass;
      `build-app-catalog.py --check` current; `pytest tools/scripts` 18 passed.
- [ ] CI green on the new paths. (evidence: PR run id, added when pushed)
- [ ] Evidence PR + run id appended to this phase.

Risk: medium (many references). Rollback: revert the single atomic commit;
then `pip uninstall` the new distributions and reinstall (pip does not remove the
old `*.dist-info` on a rename).

---

## R2. Delete the stale root `app/`

- [x] Prove nothing references it: the only `app[\\/](entry|build|code-linter)`
      match is the `$app` variable in `tools/scripts/install-to-device.sh`.
- [x] `tools/scripts/build.ps1` is the gate, and it is green after the deletion:
      `BUILD SUCCESSFUL in 2 min 574 ms`. (evidence: build output)
- [x] `git rm -r -- app` removed the 2 tracked files and `git clean -fdx -- app`
      removed the ignored `.idea/`; `Test-Path app` -> `False`.
- [x] No `.gitignore` entry existed solely for it (all app patterns are `**/...`).
- [x] `README.md` tree has no root `app/`.
- [ ] CI green for the deletion. (evidence: PR run id, added when pushed)

Risk: low. Detector: the HAP build fails immediately if anything depended on it.

## R3. `services/pc-agent` -> `services/bridge`, package `hopa_bridge`

One atomic commit (move + imports + pyproject + CI + scripts + docs).
Decision (ADR-0008): **the command stays `pc-agent`**; `hopa-bridge` is the alias.

### R3.1 Move and rename

- [x] `git mv services/pc-agent services/bridge` (`services/pc-agent` no longer
      exists).
- [x] `git mv services/bridge/src/hopa_pc_agent services/bridge/src/hopa_bridge`.
- [x] Imports rewritten in `services/bridge/**` **and** `evals/**`.
      (evidence: `pytest services/bridge evals` -> 362 passed)
- [x] `services/bridge/pyproject.toml`: `name = "hopa-bridge"`, scripts
      `hopa-bridge` + `pc-agent` alias, first-party `hopa_bridge`.
- [x] `mcp_server.py` `SERVER_NAME` -> `hopa-bridge`; `tests/test_mcp.py` asserts
      the new literal. `cli.py` keeps `prog="pc-agent"` (the command name).
- [x] `render.yaml`: install `./services/bridge`, run `python -m hopa_bridge relay`
      (the relay stays here until R4).
- [x] Cross-distribution note: bench/baseline import `hopa_bridge` without a
      declared dependency; the install-order line is in each README.
- [x] `services/bridge/README.md`: title and install line follow the name.

### R3.2 References

- [x] All scripts: `run-agent.ps1`, `run-phone.ps1`, `run-laptop.ps1`,
      `bridges.ps1`, `run-bench.ps1|sh`, `run-tests.ps1|sh` - install paths and
      `-m hopa_bridge`.
- [x] `.github/workflows/ci.yml` (job "bridge + evals", step "pytest (bridge)"),
      `.github/dependabot.yml`.
- [x] `README.md`, `CLAUDE.md`, `CONTINUE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`,
      `.github/PULL_REQUEST_TEMPLATE.md`, `.env.example`.
- [x] `docs/operations/sbom.json`, `owners.md`.
- [x] `docs/architecture/{data-flow,overview,target-structure}.md`,
      `docs/guides/{setup,pc-bridge}.md`, `docs/reference/*`,
      `docs/product/*`, `docs/plan/README.md`.
- [x] `tools/scripts/ui-smoke.py`, `repair-chats.py` strings.
- [x] `apps/harmony/phone/.../BridgeWizard.ets` prints `-m hopa_bridge`.
- [x] `docs/history/*` and ticked `docs/plan/phase-*.md` untouched (frozen).

### R3.3 Gates

- [x] `rg -n "hopa_pc_agent"` -> 0 outside frozen docs and this plan.
- [x] `pytest services/bridge` + `pytest evals` -> 362 passed; `ruff check`
      clean; 20 bench tasks valid.
- [x] `python -m hopa_bridge --help` works; `pc-agent --help` works (alias).
- [ ] Device smoke: `devices`, `observe`, `screenshot` - BLOCKED: `hdc list
      targets` is empty (both devices off USB).
- [ ] Bridge smoke + laptop `Connected.` - BLOCKED: same reason.
- [ ] Relay smoke against the Render preview (render.yaml changed here).
- [ ] CI green; evidence PR + run id.

Risk: medium-high. Rollback: revert the atomic commit, `pip uninstall hopa-bridge`,
reinstall, and revert `render.yaml` + redeploy if the relay line moved.

## R4. Split the relay **server half** into `services/relay`

Goal: the relay host installs only relay code; a PC still keeps `cloud-link` and
`hdc-tunnel`, so a PC never needs the relay package.

- [ ] Confirm the cut with `rg -n "class |^def " services/bridge/src/hopa_bridge/{relay,tunnel,ws}.py`:
      server: `Relay`, serve loop, `TunnelRegistry`; PC: `HdcTunnel`,
      `serve_hdc_tunnel`, `cloud-link`.
- [ ] `services/relay/src/hopa_relay/` takes the server half + `ws.py`; the PC half
      stays as `services/bridge/src/hopa_bridge/tunnel_pc.py` (renamed file, same
      behaviour).
- [ ] `services/relay/pyproject.toml`: `name = "hopa-relay"`,
      `hopa-relay = "hopa_relay.cli:main"`, no dependency on the bridge.
- [ ] Split the CLI: relay subcommands out of `hopa_bridge/cli.py` into
      `hopa_relay/cli.py`; `cloud-link` and `hdc-tunnel` stay in the bridge CLI.
      Two argparse roots, no shared `common/` module (duplicate ≤10 lines if needed).
- [ ] Move tests: `test_relay.py`, `test_tunnel.py` (split: registry vs HdcTunnel),
      `test_ws.py`; keep fake sockets local.
- [ ] `render.yaml`: build `./services/relay`, start `python -m hopa_relay relay`.
      Own commit; the deploy gate is deferred (see below).
- [ ] Deprecation: `hopa-bridge relay` prints "moved to hopa-relay" and exits 2 for
      one release.
- [ ] Docs: `guides/pc-bridge.md`, `architecture/overview.md` diagram,
      `reference/protocols.md` (R5).
- [ ] CI: install + ruff + pytest for `services/relay`.
- [ ] Gates that can be proven without a hosting account:
      - [ ] `pip install --no-deps ./services/relay` in a clean venv (the same
            build command the blueprint uses);
      - [ ] `python -m hopa_relay relay --host 127.0.0.1 --port <free>` and
            `GET /health` on that port (same start command, local host);
      - [ ] bridge and eval suites green; `run-agent.ps1 hdc-tunnel` still works
            (the PC half is intact).
- [ ] `tools/checks/check-render.py`: `render.yaml` parses and every path and
      command in it points at something that exists, so a rename cannot silently
      break the deploy. Added to CI.
- [ ] [DEFERRED: no deploy access] Render preview healthy. Owner: whoever holds
      the Render account. They verify the preview, then production; nobody without
      that access may tick this box.
- [ ] Evidence: CI run id, a `curl` of the local relay `/health`, and the
      check-render output.

Risk: medium (prod deploy). Rollback: revert package commit, then render commit,
then redeploy; `pip uninstall hopa-relay`.

---

## R5. Freeze the bridge API in `contracts/` (against the real files)

No runtime change. Written against `bridge.py` + `bridge_pool.py`, since the
`api/` split does not exist yet.

- [x] `contracts/openapi/bridge.v1.yaml` covers the real surface, 21 paths:
      `/health`, `/whoami`, `/pair`, `/refresh`, `/observe`, `/tap`, `/type`,
      `/swipe`, `/screenshot`, `/launch`, `/foreground`, `/stop`, `/focus`,
      `/key`, `/voices`, `/images`, `/images/{id}`, `GET|POST /chats`,
      `GET|POST /sessions`, `/transcribe`, `/speak`. (evidence: checker reports
      "ok 21 spec path(s), 20 code route(s), 1 prefix route(s)")
- [x] Auth is in the spec: bearer token, bootstrap vs paired token, the 12-hour
      lifetime, `X-Hopa-Role` routing, `X-Hopa-Read`, error body.
- [x] `contracts/openapi/README.md`: same-PR rule, both-directions check, prefix
      routes, versioning.
- [x] `tools/checks/check-openapi.py` reads the `self.path ==` chain in
      `bridge.py` + `bridge_pool.py`, allows declared prefixes, fails both ways;
      unit tests in `tools/scripts/test_check_openapi.py` (5 tests).
- [x] `docs/reference/protocols.md` indexes bridge HTTP, relay, brain, MCP and the
      four schemas; the `protocols` row in `docs/README.md` now points at it.
- [x] CI step "Bridge contract"; `check-links.py` and `pytest tools/scripts`
      green. (evidence: `pytest tools/scripts` -> 23 passed)

Risk: low. Deferred decision: `/v1` prefix (recorded; not done here).

## R6. A device seam in the bridge — protocol only, no folder split

`device.py` cannot become `device/` while the module `device.py` exists (Windows
case-insensitive FS). So R6 adds a protocol and adapters **in flat files**; the
folder split is a later, separate plan.

- [ ] `services/bridge/src/hopa_bridge/device_port.py`: `DevicePort` protocol —
      `observe`, `tap`, `type`, `swipe`, `screenshot`, `launch`, `foreground`,
      `apps`, `serial`, `platform`.
- [ ] `device_harmony.py`: adapter over today's `device.py`, covering the direct
      `device.hdc.shell` / `file_recv` calls in `bridge.py`.
- [ ] `bridge.py` / `bridge_pool.py` take a `DevicePort`; only `device_harmony.py`
      imports `hdc.py`.
- [ ] Registry gains `platform` (default `harmony`) next to `role`; existing
      `devices.json` unchanged.
- [ ] Tests: reuse the existing `FakeDevice` (`evals/baseline/tests/conftest.py`)
      — relocate or wrap it, do not add a third fake.
- [ ] `check-structure.py`: add a Python rule "only `device_harmony.py` imports
      `hdc`" — this is new code, not a retarget of existing rules.
- [ ] Gates: `pytest services/bridge`; hardware observe/tap/screenshot; laptop
      app unaffected.

Risk: medium. Rollback: revert the single commit; no data changes.

---

## R7. Record the backend boundary (ADR only, no package)

- [ ] ADR `docs/adr/0010-loop-ownership.md`: the loop stays on the device until a
      backend runtime exists; client apps talk over `contracts/`; `services/backend`
      is a future phase with its own plan.
- [ ] `docs/architecture/target-structure.md` gets a "superseded by" note on the
      parts this plan changes (top-level names, harness).
- [ ] No package, no CI job, no `runtime/` stub.

Risk: none. Rollback: revert the doc commit.

---

## R8. Rules, docs, and the checks that keep the tree honest

- [x] `tools/checks/check-tree.py`: directory names only; skips dot-directories
      and build/vendor output; allow-lists the top level; fails on `harness/` and
      on `utils|helpers|common|misc|shared` at any depth.
      (evidence: `0 tree violation(s)`)
- [x] `tools/scripts/test_check_tree.py`: five tests - the real repo, an unknown
      top-level folder, `harness/`, a nested junk drawer, and ignored build/dot
      directories. (evidence: 5 passed)
- [x] `check-links.py` extended to `contracts/**` and to `README.md` under
      `apps/`, `services/`, `evals/`, `tools/`. It immediately found a stale
      `../docs/brain.md` in `services/brain/README.md`, now
      `../../docs/reference/brain.md`.
- [x] `README.md` repository map includes `contracts/` and `tools/`;
      `CONTRIBUTING.md` gained the "where does a new file go?" table (top level
      then layer, with the two absolute rules); `CLAUDE.md` paths refreshed in
      R1/R3; `docs/plan/README.md` links this plan without adding boxes to the
      M-plan. (evidence: links 0 broken)
- [x] `docs/architecture/layers.md` routes by top level (R0); `overview.md` and
      `data-flow.md` follow the new paths (R1/R3).
- [x] CI step "Tree rules"; gates green: `check-tree`, `check-structure
      --strict`, `check-links`, `plan-status --lint`, `pytest tools/scripts`.

Risk: low.

## R9. Reserve the platform folders (README only)

- [x] `apps/android/README.md`: thin client, Compose shell, `AccessibilityService`
      adapter implementing `DevicePort`, contract-only traffic, first steps.
- [x] `apps/windows/README.md`: WinUI shell, UI Automation adapter, the sparse-tree
      rule, contract-only traffic.
- [x] `docs/guides/adding-a-platform.md`: the `DevicePort` method table, the four
      honesty rules, and the checklist (adapter, registry platform value, fake
      adapter tests, hardware evidence, contract note).
- [x] Gate: `check-links.py` 0 broken (it now covers `apps/**/README.md` from R8)
      and `check-tree.py` accepts the two new folders.

Risk: none.

## Acceptance gates

| Gate | Command | Applies after |
|---|---|---|
| Python suites | per package, as CI does: `pytest services/bridge`, `pytest evals/bench`, `pytest evals/baseline`; plus `pytest services evals` once R0 adds `--import-mode=importlib` | R0 |
| Lint (scoped) | `ruff check services evals tools` / `ruff format --check …` | R0 |
| Structure | `python tools/checks/check-structure.py --strict` | every phase |
| Tree | `python tools/checks/check-tree.py` | R8+ |
| Contracts | `python tools/checks/check-openapi.py` | R5+ |
| Links | `python tools/checks/check-links.py` (extended in R8) | every phase |
| Plan | `python tools/scripts/plan-status.py --plan docs/plan/refactor --lint` | every phase |
| Catalogue | `python tools/scripts/build-app-catalog.py --check` | every phase |
| Build | `tools/scripts/build.ps1` | R2, R3 |
| Device | laptop app `Connected.` + one observe/tap | R3, R6 |
| Relay | `/health` on preview and on the PC half's `hdc-tunnel` | R4 |

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
