# 8. Phase 3 â€” ArkTS core on device (6â€“10 weeks)

### 8.1 Port scope and skeleton

- [ ] ADR: exactly which modules move on device
- [ ] `apps/harmony/core` file layout mirrors Mika's core directories
- [ ] Shared JSON contracts package for JVM and ArkTS
- [ ] Golden-file corpus shared by both implementations
- [ ] Parity test harness defined

### 8.2 Port modules

- [x] `Types`, `ToolRegistry`, `ActionExecutor`, `ApprovalPolicy` (evidence: apps/harmony/core/src/main/ets + hypium tests in apps/harmony/core/src/test)
- [ ] `uistate` (46 files) â€” screen model
- [ ] `observation`, `verify`, `record`
- [ ] `knowledge` (routing, channel, catalog)
- [x] `agent` loop and context builder (evidence: apps/harmony/core/src/main/ets/AgentLoop.ets + AgentLoop.test.ets)
- [ ] Decide per remaining Mika module (action, run, gate, context, prompt, settings, trigger, usage, trace, net, remote, mcp, oauth, workspace, general, assembly, selfcheck): port, rewrite or drop; record in Appendix A.2b
- [ ] `memory`, `skills`
- [x] `model` client over `@ohos.net.http` (evidence: apps/harmony/core/src/main/ets/OpenAiClient.ets (http from @kit.NetworkKit))
- [ ] Serialization without kotlinx (`@ohos.util.json` or generated codecs)
- [ ] File storage over `@ohos.file.fs`
- [ ] Secure storage over Asset Store Kit / HUKS
- [x] Settings over `@ohos.data.preferences` (evidence: apps/harmony/entry/src/main/ets/service/SettingsStore.ets + verified persistence on the emulator: provider survived a restart)
- [ ] Remove the JVM service from the decision path behind a feature flag
- [ ] Unit tests for every ported module (hypium)
- [ ] Golden-file parity: 200 cases
- [ ] Differential fuzz: 100 random tasks, same decisions
- [ ] Decision latency < 100 ms excluding the model
- [ ] `docs/history/port-log.md` complete

### 8.3 On-device model plumbing

- [x] Provider settings UI and storage (evidence: Settings tab Select + SettingsStore; endpoint/model/provider persist, API key is memory-only by design)
- [x] Streaming responses (or documented non-streaming) (evidence: docs/architecture/overview.md section 7: non-streaming, timeouts documented)
- [ ] Timeout, retry, backoff
- [ ] Token and cost caps per task
- [ ] Offline behavior: clear error, no silent retry loop
- [ ] Model fallback list
- [x] Key never logged (evidence: no logging call in OpenAiClient.ets or Index.ets; key only used in the Authorization header; documented in docs/architecture/overview.md section 7)

### 8.4 Model quality and context

- [ ] Prompt versioning and changelog
- [ ] Context-window management and summarization for long runs
- [ ] Determinism policy (temperature, seed) documented
- [ ] Model evaluation matrix across at least two models
- [ ] Rate-limit handling with backoff
- [ ] Cost budget enforced per task and per day
- [ ] Hallucinated-ref detection (ref not in the current observation)
- [ ] Model data-residency note for the chosen provider
- [ ] Provider safety-filter behaviour documented
- [ ] Prompt and response logging redacted
- [ ] Prompt/context caching and reuse measured and enabled where the provider supports it
- [ ] Local/offline model option evaluated and decided

### 8.5 Exit criteria (M3)

- [ ] The loop runs on device with no PC
- [ ] 200/200 parity cases pass
- [ ] All Phase 2 bench tasks run through the ArkTS core
- [ ] JVM service is optional, not required

### 8.6 ArkTS runtime engineering

- [ ] Heavy parsing runs in TaskPool or Worker, not on the UI thread
- [ ] UI-thread blocking budget measured and met (< 16 ms per frame)
- [ ] On-device memory ceiling measured under a 30-step task
- [ ] Core cold-start budget defined and measured
- [ ] Core bundle-size budget defined and met
- [ ] Exception and error conventions consistent across modules
- [ ] Logging framework with levels, trace id, rotation and redaction
- [ ] Record writes are crash-safe (temp file + atomic rename)
- [ ] Feature flag switches between JVM service and on-device core
- [ ] Rollback to the JVM service documented and tested
- [ ] Deprecation policy for internal APIs
- [ ] Long-running task survives app backgrounding per platform rules
- [ ] No `any` in ArkTS core; strict mode on
- [ ] Dependency review for every `ohpm` package

---

