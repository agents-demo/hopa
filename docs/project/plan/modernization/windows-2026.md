# Windows client: 2026 modernization plan

Status: **proposal; not started.** This plan changes engineering foundations,
not product behaviour. Semantic parity with Android stays the reference
([ADR-0027](../../../design/decisions/0027-windows-semantic-parity.md)); the
Android, sidecar and Windows suites stay green in every phase.

This is a **revision after an independent critique**. The accepted changes:
the version baseline was corrected, `.NET 10` is now the first security task,
Protobuf was dropped, schema validation was split from codegen, signing was moved
earlier and split into sign/SBOM/clean-VM, the CDP work was reduced to a spike,
and the "modern" claims that did not survive the repo were removed.

"Modern" here means **supported, typed, observable, reproducible and cheap to
change**, not "newest framework". The file lives outside
`docs/project/plan/windows/` because `tools/scripts/plan-status.py` counts that
directory's `Phases` sections; a second plan there would corrupt the Windows
plan's completion percentage.

## 0. Scope and non-goals

In scope:

- `apps/windows/Hopa.Windows` (WPF host);
- `apps/windows/sidecar` (Kotlin engine host);
- shared `core/**` only where the Windows client needs a seam;
- protocol, stores, CI, packaging and developer checks.

Not in scope:

- a product rewrite or a second engine;
- changing approval, privacy or parity semantics;
- a HOPA-operated cloud service. The **user-configured model endpoint** is the
  only outbound path and is already part of the product;
- auto-update or telemetry upload;
- a WinUI/Avalonia rewrite before an ADR proves it pays for itself;
- touching Android behaviour beyond keeping it compiling and green.

## 1. Principles

1. **Previous signed MSI is the rollback.** No phase keeps an EOL runtime alive
   as a fallback.
2. **Strangler, not big bang.** One reviewable PR per checkbox family; the old
   path stays until the new one has evidence.
3. **Boring where it matters.** UIA, approval, secrets and packaging prefer
   proven primitives over fashion.
4. **Co-shipped host and sidecar.** They are released together; version
   negotiation is a readable hard failure, not a compatibility matrix.
5. **Measure on a named workload.** A phase that cannot name the machine,
   sample size and workload does not start.
6. **No framework change without an ADR** with a rollback. The ADR-0021 pin of
   ".NET 8 for the first release" is amended for `.NET 10`, not ignored.

## 2. Baseline (verified against this checkout)

| Area | Today | Assessment |
|---|---|---|
| .NET | SDK **10.0.201** installed; product projects target `net8.0-windows` | **.NET 8 LTS ended 2026-11-10**; the shipped self-contained MSI runs EOL bits |
| Kotlin/Gradle | Kotlin **2.4.21**, AGP **9.5.1**, Gradle **9.6.0** | already newer than this plan first assumed; do not downgrade |
| Second Kotlin | `tools/scripts/brain.sh` pins **2.1.0** for the standalone brain | two compilers; retire one |
| JDK | Gradle toolchain **17** | keep 17 bytecode for Android; ship a newer jlink runtime |
| UI | WPF, partial classes, code-behind, **existing** `ChatViewModel`, `ConversationsViewModel`, `RunRailViewModel` | state is partly modelled; not greenfield MVVM |
| Host composition | manual `new`, static helpers, no composition root | simple, but global state |
| IPC | NDJSON v1; C# reads dynamic `JsonObject` keys; Kotlin has 392-line `Protocol.kt` builders | stable, drift-prone, no DTO mirrors to delete |
| Turn | `step` events already stream live; `turn.start` waits for terminal `turn.end` | steps exist; **token streaming** does not |
| Browser | WebView2 DOM refs + `--web-check` form fill/submit | shipped; "stable refs" is wrong, stale-ref refusal is the design |
| Vision | per-step PNG frame, no downscale/cap/budget; MIME sniff; provider error body leaks up to 300 bytes | newest surface, missing from the old plan |
| Records/stores | hash chain; `memory.json`, `skills.json`, records, recipes, chat, settings | schema changes are data migrations |
| Packaging | WiX 5 MSI + zip + SHA-256; unsigned; x64-only; version hard-coded in two places; no WebView2 prerequisite | release gate is not met |
| Tests | unit, integration, sidecar, desktop scripts | strong; desktop needs an interactive session |
| Desktop CI | self-hosted workflow exists; runner not registered | skipped by default; cannot be a PR gate |

## 3. Target state (end of plan)

- `.NET 10` self-contained for every Windows project; users never install .NET.
- Kotlin **2.4.x** as the only compiler; `brain.sh` no longer pins 2.1.0.
- Gradle toolchain stays **17** for Android bytecode; the sidecar package ships
  a **JDK 21** jlink runtime. JDK 25 is not adopted without a product reason.
- A composition root with constructor injection; no new code-behind in touched
  files; existing view models are consolidated, not rewritten.
- JSON-Schema-validated frames with golden tests; codegen only if measured
  drift justifies it.
- Structured logs, correlation IDs, in-memory `ActivitySource`/`Meter`, and
  redaction tests. No default OTLP socket or upload.
- Token streaming for the sidecar; `step` stays as it is.
- A CDP accessibility-tree spike with an explicit exit criterion; DOM refs
  remain the shipped fallback.
- Signed **exe and MSI**, timestamped, verified, with SHA-256, SBOM and a
  clean-VM smoke that is explicitly nightly/release, not a PR gate.
- A stated OS/runtime/architecture floor.

## 4. Phases

Each phase ends with a **Gate** and evidence under
`docs/project/evidence/M<n>-*.md`. A phase is not done because code merged; it
is done when the evidence exists.

### M0. Guardrails, procurement and baseline (1-2 weeks)

- [x] `global.json` with `rollForward: latestPatch`; Central Package Management
      with `RestoreLockedMode` in CI.
- [x] Record the **named** baseline workload: machine, Windows build, 20 runs,
      cold start, first paint, turn p95, idle memory, zip/MSI size, suite time.
      Evidence: `docs/project/evidence/M0-baseline.md`. The first main-window
      handle is the first-paint proxy; startup outliers keep p95 high.
- [x] Decide the supported OS floor (Windows 11; Windows 10 is EOL) and the
      architecture (x64 only for v0). Evidence:
      `docs/project/plan/modernization/m0-decisions.md`.
- [x] Decide WebView2 policy: Evergreen with a minimum version check, or fixed
      runtime; record it. Evidence: `m0-decisions.md`.
- [x] Amend ADR-0021 for `.NET 10`; add a signing ADR covering PFX, certificate
      store and Trusted Signing. Evidence: ADR-0028, ADR-0029.
- [ ] Start signing procurement now: identity validation, certificate profile,
      timestamp URL, and the exe+MSI signing order. No code waits on it.
      Checklist and owner are in `m0-decisions.md`; validation is calendar work.
- [x] Decide **JSON Schema**, not Protobuf. Evidence: ADR-0028. Golden frames
      are the first M2a deliverable.
- [x] Move this plan out of the counted Windows plan directory and use the
      `Gate:`/evidence convention.
- [ ] Retire the standalone Kotlin 2.1.0 pin in `tools/scripts/brain.sh`.

**Gate:** engineering guardrails, baseline and decisions are in place; signing
procurement remains an external calendar gate. No product behaviour changed.

### M1a. .NET 8 -> .NET 10 (1 week, security first)

- [x] Move the five Windows projects to `net10.0-windows` (host, DevTools,
      checks, tests, integration tests) and the fake engine to `net10.0`.
- [x] Update WebView2, FlaUI and test packages; fix warnings. The package set
      now builds with 0 warnings; `System.Drawing.Common` was unnecessary and
      `WFO0003` is suppressed with the WPF-manifest rationale.
- [x] Update both workflows (`ci.yml`, `windows-desktop.yml`) to .NET 10.
- [x] Run a **behavioural** smoke: tray/toast, WebView2, UIA, takeover,
      vision and self-contained publish. Evidence: `M1a-net10.md`.
- [ ] Run the voice bridge round-trip; it needs a live bridge URL and was not
      available in this smoke.
- [ ] Keep the previous **signed MSI** as rollback; the signed artifact does
      not exist yet (M7a). .NET 8 bits are not kept.

**Gate:** all suites green on .NET 10; the smoke covers tray, toast, WebView2,
UIA, takeover, vision and a self-contained start without machine .NET. Voice and
the signed rollback remain external.

### M1b. Kotlin/JDK truth (1 week)

- [ ] Treat Kotlin 2.4.21 as the baseline; no downgrade. Verify Android, sidecar
      and shared `core` modules together; a Kotlin bump is an Android bump.
- [ ] Keep the Gradle `jvmToolchain(17)`; ship a **JDK 21** jlink runtime for
      the sidecar and assert `java -version` in the package.
- [ ] Record why JDK 25 is not adopted (image size, no product value).
- [ ] Delete the second Kotlin compiler path (`brain.sh`).

**Gate:** Android + sidecar green on the same Kotlin; package runtime reports
Java 21; the standalone 2.1.0 compiler is gone.

### M2a. Schema and golden frames (2-3 weeks)

- [ ] JSON Schema for every frame family and the open `op` unions; keep the
      NDJSON v1 wire.
- [ ] Capture golden frames from the current build; validate them on both ends
      in tests.
- [ ] Add a drift check: schema vs Kotlin builders vs C# reads vs `protocol.md`
      examples.
- [ ] Separate the **run-record hash chain** from schema evolution: old records
      must still verify with a committed fixture.
- [ ] Add version/format tags to persisted stores and a migration test from the
      current release.

**Gate:** zero drift on the golden corpus; old records verify; a stored fixture
from the previous release loads. No codegen yet.

### M2b. Typed frames, only if measured drift justifies it (1-2 weeks, conditional)

- [ ] Replace `Protocol.kt` builders and `EngineHostClient` string keys with
      typed frames, one family per PR.
- [ ] Keep the terminal record schema stable; do not regenerate hashing.
- [ ] If drift is already zero and the typed gain is small, stop. Record the
      decision.

**Gate:** either typed frames with no hand-written field lists, or a written
decision to keep the validated dynamic path. Protobuf is not an option.

### M3. Composition root and view-model consolidation (3-4 weeks, after W10/W11)

- [ ] Introduce a `ServiceCollection` composition root and constructor
      injection. Generic Host is optional, only if hosted services/config need
      it.
- [ ] Migrate `SettingsWindow` and `MainWindow` state incrementally; no new
      code-behind in touched files.
- [ ] Keep existing view models; adopt CommunityToolkit.Mvvm only for new ones.
- [ ] Re-run `--p5-check`, `--web-check` and `--vision-check` in the same PR;
      a refactor must not invalidate W10/W11 transcripts.

**Gate:** the composition root has no hidden `new` service graph; new VM tests
cover turn/paused/plan/error; the three evidence commands still pass.

### M4. Observability and privacy (2 weeks)

- [ ] Structured `ILogger` fields while keeping the text log pane readable.
- [ ] Correlation id across host, sidecar, device and browser.
- [ ] `ActivitySource`/`Meter` with an in-memory ring buffer surfaced on the
      existing Self-check page; no default OTLP listener or upload.
- [ ] Redaction corpus includes the vision path and the
      `OpenAiClient` provider-error body; screen text, goals, tokens and keys
      never reach a log, screenshot name or crash dump.
- [ ] Log retention policy tied to the privacy page.

**Gate:** one trace explains a turn; privacy tests fail on a leak; p50/p95
visible on the diagnostics page; retention documented.

### M5. Token streaming, not step streaming (2-3 weeks)

- [ ] Add `ModelPort.stream` for token streaming, used by the sidecar; record
      the Android impact explicitly.
- [ ] Parse OpenAI-compatible SSE, cancellation and partial failures; no retry
      storm.
- [ ] Keep `step` events as they are; `turn.end` remains authoritative.
- [ ] Render tokens without layout thrash; keep the final record schema.

**Gate:** with the scripted model on the named VM, first token < 1 s; cancel
leaves no step after the cancel; terminal `turn.end` arrives within 2 s; replay
verifies the chain.

### M6. Browser CDP spike (3 days + tests)

- [ ] Spike `Accessibility.getFullAXTree` inside WebView2 on three fixture
      pages (local form, article, app shell).
- [ ] Exit criterion: AX tree gives strictly better element names/roles than
      the DOM script; otherwise keep DOM refs.
- [ ] Add policy tests for permissions, downloads, navigation and profile
      isolation either way.
- [ ] Remove "stable refs" from the plan: stale-ref refusal is the design.

**Gate:** a written adopt/keep decision with the three-page comparison; security
tests pass; no click/type rewrite on CDP `Input` without evidence.

### M7a. Signing, version and installer prerequisites (1-2 weeks, release gate)

- [ ] One version source for MSI/product/zip; no hard-coded duplicate.
- [ ] Sign **the exe and the MSI**, timestamp both, then hash; support PFX,
      certificate store and Trusted Signing as separate paths.
- [ ] Never pass a PFX password on the command line; use a secret env var or
      the store.
- [ ] Name unsigned artifacts `-unsigned`; do not let them look releasable.
- [ ] Add a WebView2 Evergreen prerequisite or launch condition; state x64.
- [ ] Set an MSI/zip size budget and record it.

**Gate:** `signtool verify /pa` passes for exe and MSI on a clean machine; the
hash is written after signing; the installer refuses a missing WebView2.

### M7b. SBOM and licences (3-5 days)

- [ ] Reuse `tools/scripts/license-check.py`; do not duplicate it.
- [ ] CycloneDX for .NET, Gradle and the jlink module list (the runtime tree is
      otherwise invisible).
- [ ] Fail on a forbidden licence; attach SBOM to release artifacts.

**Gate:** SBOM covers app, jars and jlink modules; licence gate is required.

### M7c. Clean-VM smoke (nightly/release, interactive)

- [ ] Named autologon VM (not session 0) with the signed MSI.
- [ ] Assert `runtime\bin\java.exe`, `sidecar\lib` and `Hopa.Windows.exe`.
- [ ] One PC turn and one phone-approved turn; use a gateway double or a
      documented manual phone step.
- [ ] Commit the transcript and screenshots; this is **not** a PR gate.

**Gate:** signed MSI on a clean VM passes both turns; the evidence names the VM
and the phone/gateway path.

### M8. UI decision, not a rewrite (2-3 days)

- [ ] ADR comparing WPF, WinUI 3/WinAppSDK and Avalonia on UIA, WebView2,
      accessibility, packaging and cost.
- [ ] Adopt only with a threshold: >= 20 % faster cold start **and** no UIA
      regression; otherwise keep WPF.
- [ ] Keep theme/design-token work as a separate polish backlog.

**Gate:** ADR with a rollback and a threshold; no prototype budget unless a
named user-visible defect requires it.

### M9. Decommission (inside each phase)

- [ ] Delete the old path in the same phase that replaces it; no "ongoing"
      cleanup phase.
- [ ] Add the "no new hand-written frame" check only after M2 decides.
- [ ] Keep `parity.md`, `total-parity.md` and `parity-evidence.md` current.

**Gate:** each phase removes at least as much old surface as it adds, or says
why not.

## 5. Sequence and capacity

One owner, roughly **18 weeks**. This work displaces parity work: it does not run
silently beside W10/W11 or the P5 human signature.

| Order | Phase | Effort | Why |
|---:|---|---:|---|
| 1 | M0 | 1-2 w | baseline, signing procurement, JSON Schema decision |
| 2 | M1a | 1 w | .NET 8 is EOL; security first |
| 3 | M1b | 1 w | one Kotlin, JDK 21 runtime |
| 4 | M2a | 2-3 w | schema + golden + migrations; highest drift payoff |
| 5 | M7a | 1-2 w | signing lead time; start procurement in M0 |
| 6 | M3 | 3-4 w | composition root after W10/W11 evidence |
| 7 | M4 | 2 w | traces and privacy |
| 8 | M5 | 2-3 w | token streaming |
| 9 | M6 | 3 d | CDP spike, keep or kill |
| 10 | M7b/c | 1-2 w | SBOM and clean-VM release gate |
| 11 | M8 | 2-3 d | UI decision only |

Rule: **no M3/M5/M6 file churn while a W10/W11 evidence transcript is pending**.
Re-run the evidence commands in the same PR as any refactor of the files they
drive.

## 6. Acceptance metrics

| Area | Metric | Workload |
|---|---|---|
| Build | zero new warnings; analyzers clean; locked restore | CI |
| Protocol | zero drift on golden corpus; old records verify | committed fixtures |
| Startup | median of 20 cold starts on named VM; no >10 % regression | M0 harness |
| Turns | p95 no >10 % regression; token first <1 s; cancel no next step | scripted model |
| Privacy | zero screen text/secrets in logs, screenshots, crash dumps | redaction corpus |
| Diagnostics | p50/p95 for last 20 turns visible | Self-check page |
| Package | signed exe+MSI; `signtool verify`; hash; SBOM; clean-VM two turns | release evidence |
| Parity | every row has an artifact or a written platform reason | parity matrix |

"Deterministic MSI" is not a metric: WiX summary timestamps and generated package
codes are not reproducible. Reproducible **inputs**, normalised zip timestamps
and a recorded MSI hash per build are the realistic target.

## 7. Hidden migrations and compatibility

- **Stores**: memory, skills, records, recipes, chat, settings. Add format
  versions and a migration test with a fixture from the current release.
- **Record hash chain**: field renames/reordering invalidate old records. Keep
  `RunRecordSerializer`/`ObservationHasher` stable and add "old record still
  verifies".
- **Gateway schema**: `contracts/schemas/gateway.v1.schema.json` is shared with
  the backend and checked in CI. `$ref` or vendor it; do not fork the gateway
  state machine.
- **Settings**: sidecar `RuntimeConfig` and C# `SettingsStore` are already two
  sources of truth; do not add a third.
- **Exports**: `conversation.export` is user-visible JSON; renaming fields
  breaks saved exports.
- **JSON parsing**: `HopaJson` uses `ignoreUnknownKeys = false`. Either keep
  host/sidecar strictly co-shipped or add a tested compatibility mode; do not
  call additive fields "compatible" without a test.

## 8. Risks and mitigations

| Risk | Mitigation |
|---|---|
| .NET 10 WPF/WinForms/UIA/self-contained regressions | M1a behavioural smoke; previous signed MSI rollback |
| Kotlin bump breaks Android | treat Kotlin as Android-coupled; keep toolchain 17; joint matrix |
| Schema/codegen rewrites the wire | M2a validation first; M2b conditional; golden frames |
| MVVM/DI ceremony | composition root only; migrate two files; stop if test gain is negative |
| Streaming duplicates records | one recorder; terminal `turn.end`; cancel test |
| CDP is partial in WebView2 | spike with exit criterion; keep DOM fallback |
| Signing lead time | procurement in M0; split PFX/store/Trusted Signing; unsigned labelled |
| Clean VM needs a phone | gateway double or documented manual step; nightly/release only |
| Self-hosted runner absent | never a PR gate; hosted checks cover the rest |
| Orphan `java.exe` | job object / kill-on-close; test a crashed host |
| WebView2 runtime drift | minimum Evergreen version or fixed runtime |
| OS/ARM64 ambiguity | state Windows 11 x64 floor; ARM64 budgeted separately |
| Log retention/PII | retention policy tied to privacy page |
| App accessibility | keyboard/Narrator/high-contrast/200 % DPI check; separate from M8 |

## 9. Open questions

- JSON Schema is decided; the remaining question is how much of `protocol.md`
  is generated and how much stays prose.
- JDK 21 is the runtime target; confirm the Android Gradle matrix accepts it.
- Does token streaming work reliably for every provider the product allows, and
  what is the fallback when SSE stalls?
- Is a gateway double enough for the clean-VM phone-approved turn, or is a
  manual phone step acceptable for release evidence?
- Windows 11 only, or Windows 10 ESU for v0?
- ARM64: support it or state x64-only?

## 10. Critique disposition

Accepted:

- corrected versions and the `.NET 8` EOL urgency;
- dropped Protobuf; JSON Schema + golden frames first;
- split M2 into validation and optional codegen;
- split M7 into signing, SBOM and clean-VM;
- moved signing earlier and started procurement in M0;
- removed the false "PR gate" for clean-VM/desktop;
- corrected "step streaming" to "token streaming";
- acknowledged existing view models; M3 is consolidation, not greenfield;
- reduced CDP to a spike with a keep/kill criterion;
- cut M8 to an ADR;
- removed Generic Host as a hard requirement;
- moved the plan outside the counted Windows plan directory;
- added store/record/gateway migrations, vision privacy, orphan sidecar,
  WebView2 runtime, OS/ARM64 and accessibility risks.

Rejected or deferred:

- Protobuf: rejected for the open `op` unions, explicit nulls and record hashing.
- CDP click/type rewrite: deferred until the AX-tree spike wins.
- WinUI/Avalonia prototype: deferred to an ADR.
- Full OTel collector: deferred; in-memory diagnostics first.
