# 12. Phase 7 â€” Evaluation (continuous)

- [ ] Bench v1 (20 tasks) stable for 7 days
- [ ] Bench v2 (50 tasks, 10 apps)
- [ ] Held-out task set
- [x] Failure taxonomy with counts (evidence: harness/bench/src/hopa_bench/report.py + test_report)
- [x] Per-app success rates (evidence: harness/bench/src/hopa_bench/report.py + test_report)
- [x] Latency p50/p95 (evidence: harness/bench/src/hopa_bench/report.py + test_report)
- [ ] Cost per task
- [ ] Human evaluation rubric
- [ ] Nightly device run
- [ ] Regression gate on every PR (stub model)
- [x] Reproducible seeds and fixtures (evidence: harness/bench/tasks (20) + deterministic StubModelClient)
- [ ] Public report
- [ ] Comparison with the reference on equivalent Android tasks (clearly labelled)
- [x] `docs/product/bench.md` (evidence: docs/product/bench.md)

### 12.1 Test matrix

- [ ] Device matrix: two phones plus one tablet or foldable
- [ ] OS versions: current and previous HarmonyOS release
- [ ] Locales: en-US and zh-CN
- [ ] Network: Wi-Fi, cellular, slow, offline
- [ ] Low battery and low storage
- [ ] Interruption: incoming call and notification
- [ ] Rotation and multi-window
- [ ] Permission revocation mid-task
- [ ] App update mid-run
- [ ] Kill and restart; resume from records
- [ ] Soak test: two-hour session
- [ ] Thermal soak and low-battery run
- [ ] Captive portal and VPN run
- [ ] Monkey test: 1,000 random actions
- [ ] Golden screenshots per supported app
- [ ] Brain-service load test
- [ ] Chaos: model timeout, HTTP 500, rate limit
- [ ] Backup and restore
- [ ] Upgrade and downgrade
- [ ] Uninstall leaves no data
- [ ] Multi-user and private space
- [ ] Flaky-test detection and quarantine
- [ ] Bench authoring guide
- [ ] User corrections (â€œthat was wrongâ€) feed the eval set
- [ ] Generated API reference for the contracts
- [ ] Adversarial: prompt injection, fake UI, malicious overlay
- [ ] Adversarial: model claims payment is already approved
- [ ] Adversarial: hidden payment step in a long flow
- [ ] Benchmark-leakage check: task text never appears in prompts, memory or knowledge

### 12.2 Targets (confirm at M1)

- [ ] Bench v1 success â‰¥ 70%
- [ ] Bench v2 success â‰¥ 85%
- [ ] Payment refusal 100%
- [ ] p95 step latency â‰¤ 8 s with model
- [ ] Crash-free sessions â‰¥ 99%
- [ ] Cost per task â‰¤ target set in ADR-0006

### 12.3 Statistical rigour and SLOs

- [x] Sample size per task justified (minimum 3 runs, 30 for headline numbers) (evidence: docs/product/bench.md (3 runs, 30 for headline))
- [ ] Confidence intervals reported for headline success rates
- [ ] Environment reset between tasks (app state, locale, network, account)
- [ ] Bench task versioning and changelog
- [x] Determinism controls: pinned app versions, locale, time zone, network (evidence: docs/product/bench.md (determinism controls))
- [ ] Flakiness budget defined; flaky tasks quarantined
- [ ] Human baseline time measured for the same tasks
- [ ] Energy per task measured
- [ ] Cost model with current token prices
- [x] SLOs defined: success, latency, crash-free, cost (evidence: docs/product/bench.md (SLO targets))
- [ ] Error budget policy written
- [x] Failure attribution: brain, body, model or environment (evidence: docs/product/bench.md (failure attribution))
- [ ] Model A/B and prompt A/B harness
- [ ] Regression detection with a fixed seed set
- [ ] Public numbers reproducible from a clean checkout

---

