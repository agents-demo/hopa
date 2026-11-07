# 5. Phase 0 â€” Foundations (1â€“2 weeks)

### 5.1 Repository and process

- [x] Mark `docs/product/roadmap.md` as superseded and link this plan (evidence: docs/product/roadmap.md)
- [x] Link this plan from `README.md` (evidence: README.md)
- [x] Add `docs/adr/` with an ADR template (evidence: docs/adr/README.md)
- [x] ADR-0001: brain hosting (remote JVM first, ArkTS later) (evidence: docs/adr/0001-brain-hosting.md)
- [x] ADR-0002: knowledge format and HarmonyOS bundle mapping (evidence: docs/adr/0002-knowledge-format.md)
- [x] ADR-0003: sandbox runtime (Pyodide + QuickJS, no Linux) (evidence: docs/adr/0003-sandbox-runtime.md)
- [x] ADR-0004: ACL strategy and foreground fallback (evidence: docs/adr/0004-acl-strategy.md)
- [x] ADR-0005: PC-tethered vs standalone product split (evidence: docs/adr/0005-pc-tethered-vs-standalone.md)
- [x] ADR-0006: model provider, budget and cost target per task (evidence: docs/adr/0006-model-provider-and-budget.md)
- [ ] [BLOCKED: no Huawei developer account or ACL channel] File the accessibility ACL request in week 1; record ticket, date and contact (critical path); package ready in docs/operations/acl-request.md
- [x] Add `CONTRIBUTING.md` with the evidence rule from Â§1.1 (evidence: CONTRIBUTING.md)
- [x] Add `CODEOWNERS` (evidence: CODEOWNERS)
- [x] Add PR template with the phase checklist (evidence: .github/PULL_REQUEST_TEMPLATE.md)
- [ ] Enable branch protection on `main`; require CI
- [x] Add issue labels: `phase/0..9`, `area/core|cap|ui|bench|docs`, `risk` (evidence: phase/*, area/*, risk labels created)
- [ ] Create the project board with phases 0â€“9
- [ ] Assign an owner per phase
- [x] Write a definition of ready for starting a phase (evidence: docs/operations/definition-of-ready.md)
- [ ] Schedule a monthly risk review
- [x] Add a decision log index under `docs/adr/` (evidence: docs/adr/README.md)
- [x] Pin toolchain versions in `docs/guides/setup.md`: Python 3.12, Node LTS, DevEco 26, compileSdk 26, minCompatible 6.1.1 (API 24), CLT 26.0.0.851 (evidence: docs/guides/setup.md)
- [x] Add `.editorconfig` and formatting rules for ArkTS and Python (evidence: .editorconfig)
- [x] Add `scripts/plan-status.py` and test it (evidence: table, --json, --lint, --require-complete, --list-unchecked, decision pairs)
- [x] Add a CI job that prints plan progress and runs `plan-status.py --lint` on every PR (evidence: .github/workflows/ci.yml)

### 5.2 CI and quality gates

- [x] `ruff check` green on `pc-agent` and `bench` (evidence: CI run 42094448015)
- [x] `ruff format --check` green (evidence: CI: ruff format --check)
- [x] `pytest pc-agent` green (evidence: CI run 42094448015)
- [x] `pytest bench` green (evidence: CI run 42094448015)
- [x] `hopa_bench validate --tasks bench/tasks` green (evidence: CI run 42094448015)
- [ ] ArkTS unit tests run on a macOS runner
- [ ] HAP build runs on Linux with a mirrored CLT archive
- [ ] CI fails (not skips) when `HARMONY_CLI_TOOLS_URL` is missing on `main`
- [x] Coverage report for Python; threshold set (evidence: CI: pytest agent --cov --cov-fail-under=80 (89%))
- [ ] Coverage report for ArkTS; threshold set
- [x] `pip-audit` / Dependabot enabled (evidence: `.github/dependabot.yml` (pip + actions))
- [x] License check: Apache-2.0, NOTICE current, no GPL (evidence: scripts/license-check.py + CI security job)
- [x] Secret scan (gitleaks) in CI (evidence: security job, CI run 42144612306)

### 5.3 Environment and baseline

- [ ] Record the device matrix: emulator + one physical HarmonyOS 6+ phone
- [ ] `hdc list targets` works for both
- [ ] `pc-agent devices` works for both
- [ ] `pc-agent dump` returns a parseable layout on both
- [ ] `pc-agent screenshot` works on both
- [x] Baseline test run recorded in `docs/history/baseline-2026-11-06.md` (counts, failures) (evidence: docs/history/baseline-2026-11-06.md (local run 2026-11-05; device pending))
- [x] Baseline bench run recorded (5 tasks, pass/fail, latency) (evidence: docs/product/bench-results-v0.md (3/5, p95 4.8s))
- [ ] Model provider chosen and key stored in env, not git
- [ ] Model latency and cost measured for one call
- [x] Write `docs/history/status-2026-11-07.md` with the honest one-paragraph state (evidence: docs/history/status-2026-11-07.md)

### 5.4 Exit criteria (M0)

- [x] CI is green on `main` (evidence: CI run 42094448015; HAP and ArkTS jobs skipped)
- [x] All six ADRs merged (evidence: docs/adr/ (six ADRs))
- [ ] Baseline numbers exist and are reproducible
- [x] `plan-status.py` reports the starting count (evidence: 767 total, 3 done, 0 lint errors)

### 5.5 Programme, people and change control

- [x] Named owner for every phase (not â€œTBDâ€) (evidence: docs/operations/owners.md)
- [ ] Named reviewer for core, capabilities, bench and docs
- [x] Team skills matrix: ArkTS, Kotlin/JVM, Python, HarmonyOS a11y, security (evidence: docs/operations/owners.md (skills matrix))
- [x] Hiring or contracting gap identified for any missing skill (evidence: docs/operations/owners.md (hiring gap))
- [ ] Two-week budget approved for model calls and devices
- [x] Dependency list with owners and lead times (ACL, device, toolchain, store) (evidence: docs/operations/owners.md (dependencies))
- [x] Assumption register started (Appendix E) (evidence: Appendix E)
- [x] Open-questions register started (Appendix E) (evidence: Appendix E)
- [x] Change-control rule: plan edits need a PR and a one-line reason (evidence: CONTRIBUTING.md (pull requests))
- [x] Definition of done for a PR (tests, docs, evidence, review) (evidence: .github/PULL_REQUEST_TEMPLATE.md)
- [x] Branching and commit-message convention written down (evidence: CONTRIBUTING.md)
- [x] Semantic-versioning policy written down (evidence: docs/operations/versioning.md)
- [x] Documentation ownership map: who updates which page (evidence: docs/operations/owners.md (documentation ownership))
- [x] One-page architecture overview diagram committed (evidence: docs/architecture/overview.md)
- [x] Glossary of HOPA, Mika, ACL, a11y, observation, capability (evidence: docs/reference/glossary.md)
- [ ] Weekly 15-minute progress review using `plan-status.py`
- [ ] Plan totals and phase estimates re-baselined after this audit
- [ ] Decide how a managed / MDM device differs from a personal device, and whether HOPA supports it
- [ ] Budget approved for a device farm or a second physical phone for nightly runs
- [x] Offboarding note: where secrets, keys and accounts live (evidence: docs/operations/owners.md (offboarding))

---

