# 7. Phase 2 â€” Mika brain on HOPA body (4â€“6 weeks)

> Target: reuse Mika's pure-Kotlin core as the brain, for speed and fidelity.
> The body stays HOPA. Nothing Android-specific is copied.

### 7.1 Brain service

- [ ] Extract the ported Mika subset (Appendix A.2 and A.2b) into a standalone JVM module with zero `android.*` imports
- [x] Verify with `grep -r "android\."` returning nothing in the ported module (evidence: grep -r "android\." brain/src returns nothing)
- [x] Build with JDK 17; pin the toolchain (evidence: scripts/brain.ps1 / brain.sh (Kotlin 2.1.0, JDK 17))
- [x] HTTP API `POST /decide`: `{goal, observation, history, settings}` â†’ `{action, say, done}` (evidence: brain/src/main/kotlin/hopa/brain/Server.kt + ServerTest)
- [x] Sticky session id for multi-step tasks (evidence: BrainService.sessions + GET /session/{id})
- [x] Health and version endpoints (evidence: ServerTest health/version)
- [x] Structured logs with trace id (evidence: X-Trace-Id + JSON stderr log)
- [x] Contract tests against the JSON schema (evidence: scripts/brain-contract.py validates decision.schema.json)
- [x] No network except the model endpoint (evidence: brain/src has no outbound HTTP client)
- [ ] Dockerfile for repeatable local runs
- [ ] `NOTICE` lists every Mika file reused
- [x] `docs/history/port-log.md` started (evidence: docs/history/port-log.md)

### 7.2 Knowledge port

- [x] Copy the knowledge schema and loader (evidence: brain/src/main/kotlin/hopa/brain/KnowledgeLoader.kt (clean-room))
- [x] Inventory Mika's 23 apps and 18 sites; mark Android-only fields (evidence: docs/history/knowledge-triage.md (23 apps + 18 sites))
- [x] Triage the 23 apps: available on HarmonyOS, web-only, or absent; record the evidence (evidence: docs/history/knowledge-triage.md (replaced/app?/web-only))
- [ ] Build the HarmonyOS bundle map from `hdc shell bm dump -a`
- [ ] Rewrite `APP.md` for the 10 highest-value apps that exist on HarmonyOS
- [ ] Rewrite `APP.md` for the remaining HarmonyOS-available apps; drop absent apps with a written note
- [x] Rewrite `SITE.md` for 18 sites (domains mostly reusable) (evidence: brain/knowledge/sites (21, including LinkedIn, Uber and Uber Eats) + SiteLoaderTest)
- [x] Add 12 HarmonyOS system apps: Settings, Clock, Calendar, Contacts, Notepad, Files, Camera, Gallery, Browser, AppGallery, Petal Maps, Music (evidence: brain/knowledge/apps (12 files))
- [x] Add `pace: careful` to every irreversible app path (evidence: 12 APP.md files + KnowledgeLoaderTest)
- [ ] Add `packageAliases` for HarmonyOS bundles
- [x] Front-matter parser validates all files (evidence: KnowledgeLoaderTest (front-matter parser))
- [x] Loader unit tests (evidence: KnowledgeLoaderTest (14 assertions))
- [x] `knowledge_search` returns HarmonyOS entries only (evidence: GET /knowledge + KnowledgeLoader platform check + ServerTest)
- [x] `docs/reference/knowledge.md` explains the format and how to add an app (evidence: docs/reference/knowledge.md)

### 7.3 Routing

- [x] Port `KnowledgeStore.matchTask` (lexical, installed-first, word boundaries) (evidence: brain/src/main/kotlin/hopa/brain/Router.kt + RouterTest)
- [x] Port `ChannelAdvisor` (app vs web vs signed-in) (evidence: brain/src/main/kotlin/hopa/brain/Router.kt + RouterTest)
- [ ] Port `GuideCatalog` and the skills index
- [x] Port `packageFor` (evidence: brain/src/main/kotlin/hopa/brain/Router.kt + RouterTest)
- [x] Add installed-app listing: `pc-agent apps` â†’ `{bundle, label}` (evidence: pc-agent/src/hopa_pc_agent/apps.py + tests)
- [ ] Unknown app: list â†’ label â†’ launch â†’ generic operation
- [ ] Ambiguous match â†’ ask the user once, remember the answer
- [x] Routing tests: known app, alias, domain, unknown, two plausible (evidence: brain/src/test/kotlin/hopa/brain/RouterTest.kt (17 assertions))
- [x] Routing tests: generic words never match (`app`, `web`, `site`) (evidence: brain/src/test/kotlin/hopa/brain/RouterTest.kt)
- [ ] Bench: open 5 apps by name
- [ ] Bench: operate a freshly installed unknown app
- [x] Document the honest limit: lexical, not embeddings; no auto-learning for unknown apps (evidence: docs/history/port-log.md (honest limits))
- [ ] Pinyin and English aliases for Chinese app names
- [ ] Locale-aware matching for zh-CN and en-US
- [ ] App-not-installed detection in routing, with an install option

### 7.4 Prompts and skills

- [ ] Port 118 prompts; strip Android-only tool names
- [x] Port `intent_gate` (DISCUSS / READ / ACT) (evidence: brain/src/main/kotlin/hopa/brain/Prompts.kt + PromptBookTest)
- [x] Port `channels.md` decision order (evidence: brain/src/main/kotlin/hopa/brain/Prompts.kt + PromptBookTest)
- [ ] Port `roles/app_knowledge*.md`
- [x] Port 6 skills (9 files: manifests, references and the PDF script) and validate manifests (evidence: 6 clean-room manifests in brain/knowledge/skills + SkillLoaderTest)
- [ ] Port personal skill creation
- [ ] Port the app-notes draft â†’ trial â†’ verified flow
- [x] Prompt size budget and truncation rules (evidence: PromptBook.MAX_SCREEN_CHARS + PromptBookTest)
- [ ] Token accounting per step
- [x] Prompt-injection tests: screen text cannot issue instructions (evidence: PromptBookTest (screen text only in user message) + agent/tests/test_safety.py)
- [ ] Prompt snapshot tests (golden files)

### 7.5 Memory and records

- [ ] Port run records and the memory model
- [ ] Port `AppKnowledgeLearning`
- [ ] Learned notes attach only to known app entries (document this)
- [ ] Memory view data source
- [ ] Redaction before storage
- [ ] Encryption at rest or an explicit risk note
- [x] Export and delete memory (evidence: app Memory tab "Export data" writes hopa-export.json; "Clear facts" and per-item delete; verified on the emulator)
- [ ] Memory retention policy implemented (runs, notes, screenshots)

### 7.6 Knowledge validation and maintenance

- [ ] Per-app smoke test: launch and reach one known screen for every app in the launch set (ported + system)
- [ ] `validated` version and date in every `APP.md`
- [ ] Detect app version change via `bm dump` and mark its knowledge stale
- [ ] Knowledge rollback: pin the knowledge version per release and restore the previous one
- [ ] Selectors survive text and locale changes (ids first, text second)
- [ ] Fallback when a known screen is missing
- [ ] Contribution guide: add an app in one file
- [x] Knowledge schema and front matter validated in CI (evidence: CI brain job runs KnowledgeLoaderTest)
- [x] Track HarmonyOS vs Android divergence per app (evidence: docs/history/knowledge-triage.md (status/action table))
- [ ] Record regional and locale variants
- [ ] Verify the documents skill (PDF extraction) on HarmonyOS
- [ ] Verify the transcription skill (audio â†’ text) on HarmonyOS
- [ ] Verify the info-research skill on HarmonyOS

### 7.7 Bench v1 (20 tasks)

- [x] 20 tasks defined (Appendix B) (evidence: bench/tasks (20 valid))
- [ ] Bundle names confirmed on device (7 of 12 knowledge bundles verified; 5 apps are not on the Pura 90 image, see docs/reference/bundles.md)
- [ ] Safety tasks included (payment refusal, deny stops, takeover)
- [ ] Three consecutive runs; variance reported
- [ ] Success, steps, p50/p95 latency, tokens, cost
- [ ] Per-app breakdown
- [ ] `docs/bench-v1.md` published
- [ ] Benchmark task, fixture and screenshot licences recorded; no third-party content copied without permission
- [ ] Regression gate with the stub model in CI

### 7.8 Exit criteria (M2)

- [ ] 20-task success rate â‰¥ 70%
- [ ] Payment refusal 100% on the Bench v1 safety tasks
- [ ] Unknown app operable from `list_apps`
- [ ] No Android-only dependency in the brain
- [ ] Bench report reproducible by a second person

### 7.9 Licensing and provenance

- [ ] Apache-2.0 obligations met: copyright headers kept, NOTICE updated, changes stated
- [ ] Per-file provenance manifest: Mika path, HOPA path, modified yes/no
- [ ] No GPL, AGPL or source-available code in the ported tree
- [ ] No Android hidden API, `proot`, `adb` or `VirtualDisplay` code copied
- [ ] Knowledge content licence audit: do not copy third-party app documentation
- [ ] Prompt provenance recorded; Chinese prompts translated, not silently dropped
- [ ] Mika trademarks and product names absent from HOPA UI and docs
- [ ] Legal review of the port recorded
- [ ] Third-party notices generated from the dependency tree
- [ ] Reuse decision recorded for every Mika module (port, rewrite, drop)

---

