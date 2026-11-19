# Decision Anchors — Google Maps Navigation: Embedding Plan

- Status: proposed (awaiting decisions in §7)
- Date: 2026-11-19
- Milestones: G1–G4 (repo convention: commit subjects reference these)
- Effort: ~18–20 working days, single engineer (~4 weeks)

---

## 1. Background — what exists from this session

All anchor artifacts live in `anchor/` (this folder):

- `anchor_decisions_demo.py` — data-driven rule engine. Rules/cases/graph load
  from external JSON; every firing rule votes for a next state with a
  probability (max-aggregated); if the highest raw vote < `--threshold`
  (default 20%) the engine abstains (`ASK MODEL`). Includes `--self-test`
  (15 tests: engine properties + graph invariants + per-case expected
  outcomes) and a benchmark with simulated teacher latency.
- `anchor_navigation_rules.json` — 16 rules for "navigate from ${src} to
  ${dst} by {car|walk|public transportation}", anchored on the Google Maps UI
  state graph: s1→s2→…→s9 (route chosen, car default), s9→s10 (transit tab),
  s9→s11 (walking tab), s10→s49 (transit card), plus a deliberate 10%
  low-confidence rule that triggers the model fallback when the mode is
  missing/unknown.
- `anchor_navigation_cases.json` — 19 cases with expected outcomes (15 local
  decisions, 4 `ask_model`), all passing.
- `map_tree.xml` — Google Maps state tree captured on emulator-5554
  (Android SDK 36): 61 states, 60 transitions, full uiautomator DOMs,
  addresses templated as `${src}` / `${dst}`. Raw capture archive.
- `map_tree_to_json.py` → `map_tree.json` — operational graph: DOMs replaced
  by compact per-state signatures (resource-ids), `<point>`/`<raw_adb>`
  removed in favor of runtime-resolvable selectors (`find`, plus
  `move.delta` for drag/swipe derived from the removed points); 59/60
  transitions resolved automatically, 1 flagged `needs_review` (avatar
  picker option 2). The demo validates rules/cases against the graph and
  displays each next state with its transition.

Repo anchors the plan builds on:

- **ADR-0017** — Android acts through the bridge (adb) with on-device
  accessibility as secondary; one `DevicePort` seam.
- **ADR-0019** — tiered model access: Tier 0 shell (offline), Tier 1 LAN model
  (Ollama/llama.cpp/vLLM, OpenAI-compatible), Tier 2 cloud (today), Tier 3
  on-device = spike only.
- **ADR-0020** — Android is the active client; Harmony is frozen; shared work
  (bridge, contracts, data generators) stays client-neutral.
- **ADR-0006** — OpenAI-compatible transport, provider fallback list, cost
  caps, p95 step latency ≤ 8 s.
- **`services/brain`** — pure-Kotlin JVM routing service; README calls it "the
  contract both the JVM service and the ArkTS core will follow".
  `knowledge/apps/maps/APP.md` and `knowledge/apps/petal-maps/APP.md` exist.
- **`services/evals/bench`** — task YAML schema (`schema_version`, `id`,
  `goal`, `app`, `bundle`, `success`, `steps`, `max_steps`).
- **CLAUDE.md golden rules** — all actions through the gate pipeline
  (guards → payment approval → execute → verify → record); the payment gate
  is never weakened; `core/` is UI-free; benchmarks never bypass the gate;
  NOTICE entries for reused ideas.

## 2. Goal and scope

**Goal:** a local-first decision layer that navigates Google Maps for the
command "navigate from ${src} to ${dst} by {car|walk|public transportation}":
rules decide the next UI state; when they cannot (max vote < 20%), the
problem transfers to an SLM; the SLM's successful novel traversals and the
teacher's decisions are incrementally learned as new rules/paths at runtime.
Embedded end-to-end in HOPA (Android client + bridge, per ADR-0017/0020).

**In scope (G1–G4):** use case doc; offline graph + format; rules/cases;
real-device evaluation; SLM fallback (explore + build + evaluate); runtime
incremental learning; embedding in the loop with the full gate pipeline;
benchmark tasks.

**Out of scope (v1):** modes beyond car/walk/transit (bicycling s50 and the
menu/edit-stop branches stay in the graph but without rules); on-device model
(Tier 3 remains a spike per ADR-0019); Harmony client work (frozen per
ADR-0020); weakening the payment gate in any way.

## 3. Phases and tasks

### Phase 0 — Foundation (this session, DONE)

| # | Task | Days | Status |
|---|------|-----:|--------|
| D0 | Python decision-anchors PoC: engine + threshold fallback, templated map_tree.xml, 16 rules / 19 cases, self-tests | 1 | ✅ done |

### Phase 1 — Use case + offline graph (milestone G1)

| # | Task | Days |
|---|------|-----:|
| T1 | Google Maps use-case doc: command template, decision tiers (rules → SLM → teacher), scope, success metrics (local coverage, abstention rate, wrong-decision rate), non-goals, payment-gate stance; link ADR-0019 tiers; update `knowledge/apps/maps/APP.md` | 0.5 |
| T2 | ~~Offline graph + format~~ **mostly done this session**: schema `{meta, states[{id,label,final,signature}], transitions[{to,op,action,target,find,move,text,key,needs_review}], explored}` with `${src}`/`${dst}` templating; converter `anchor/map_tree_to_json.py` (Python, ruff-clean) drops the giant DOMs (kept as reference in `map_tree.xml`) and validates invariants (transition target exists, single-parent, final/explored consistency). **Remaining**: resolve the 1 `needs_review` transition (s23 avatar option 2) on a device, plus CI wiring | 1 (0.25 left) |
| T3 | Rules/cases data v1: re-home the 16 rules / 19 cases into brain knowledge data with a schema doc, decision space strictly aligned to graph state ids | 0.5 |

**G1 exit:** use case documented; graph artifact loads and validates in CI;
rules/cases data versioned next to the graph.

### Phase 2 — Engine port + real evaluation (milestone G2)

| # | Task | Days |
|---|------|-----:|
| T4 | Kotlin engine slice in `services/brain/src`: AnchorRule, DecisionCase, Prediction, RuleEngine (max-aggregation, threshold gate, abstain), JSON loaders; unit tests alongside RouterTest; **parity fixture** — Python and Kotlin must produce identical predictions on shared golden inputs | 1.5–2 |
| T5 | Real test-case evaluation (Python harness in `services/evals`): substitute concrete addresses, run 2–3 routes on the emulator via bridge/adb (uiautomator dump → state match on stable ids/bounds → engine prediction → execute → verify state); measure local coverage, abstention rate, wrong decisions, per-rule evidence counts | 2 |
| T6 | Triage + v1 freeze: fix rules/state matching; update probabilities from observed counts (explicitly labeled measured vs illustrative); results report | 1 |

**G2 exit:** Kotlin engine passes parity tests; real-device run documented with
honest metrics; ruleset v1 frozen.

### Phase 3 — SLM fallback (milestone G3)

| # | Task | Days |
|---|------|-----:|
| T7 | SLM exploration (runs parallel with T4–T6): evaluate per ADR-0019 tiers — (a) Tier 1 LAN small model via Ollama (Qwen3-0.6B/1.7B, Llama-3.2-3B, Phi-3-mini), (b) Tier 2 small cloud model through the ADR-0006 fallback list, (c) Tier 3 on-device spike only against S1 criteria, (d) no-model heuristic baseline (most-visited transition). Deliverable: ADR (next number after 0022) with recommendation + acceptance criteria | 1–1.5 |
| T8 | Fallback pipeline: engine abstains → SLM prompt (command + current state + child transitions, response constrained to option ids) → SLM picks next state → execute + record (`source=slm`, evidence counts); SLM also uncertain → escalate to full teacher per existing loop. Payment gate untouched: abstention never auto-bypasses approval for payment-classified actions | 1.5–2 |
| T9 | Fallback evaluation: success rate, p95 latency vs ADR-0006 budget, cost per decision, threshold sensitivity (0.2 vs tuned); report | 1 |

**G3 exit (partial):** SLM choice documented by ADR; fallback pipeline works
and is measured.

### Phase 4 — Incremental runtime learning (milestone G3)

| # | Task | Days |
|---|------|-----:|
| T10 | Store design: append-only rule/graph deltas (ids, provenance `hand|teacher|slm`, evidence counts, timestamps), versioning, merge-on-load; new paths promoted from successful SLM/teacher traversals (explored → edge) | 0.5–1 |
| T11 | Runtime APIs in brain: `addRule`, `addPath`, `promoteDecision` (teacher decision repeated ≥ k ⇒ rule with probability derived from counts), hot-reload without restart, persistence per ADR-0018 conventions; safety: never auto-promote payment-classified actions, new rules never weaken the gate | 1.5–2 |
| T12 | Tests: append correctness, reload consistency, evidence math, id collisions, corrupted-delta rejection, payment-classification guard | 1 |

**G3 exit:** incremental learning demonstrated end-to-end: an abstained case
is solved by SLM/teacher, recorded, and later decided locally.

### Phase 5 — HOPA embedding end-to-end (milestone G4)

| # | Task | Days |
|---|------|-----:|
| T13 | Loop integration (Android client per ADR-0020): brain serves anchors; the client consults the anchor engine before each model call (local decision saves a teacher call); full gate pipeline on the Android client — guards → approval → execute → verify (uiautomator diff/state match) → record (RunRecord with anchor source + evidence) | 2 |
| T14 | Benchmarks: `services/evals/bench/tasks/21-google-maps-nav-*.yaml` (goal, app `Maps`, bundle `com.google.android.apps.maps`, success = final state reached; abstention path tested; never bypasses the payment gate; stub-model run completes even when tasks fail) | 1 |
| T15 | Docs + NOTICE + milestone commits: overview/boundaries, NOTICE entries (Android `AnchorDecisionsDemo` port idea + `map_tree.xml` provenance), commit subjects referencing G1–G4 | 1 |
| T16 | Hardening + demo-ability buffer (owner shows both adapter paths per ADR-0017) | 1 |

**G4 exit:** a user/bench task "navigate from A to B by car" runs end-to-end
with the anchor engine on the Android client, falls back correctly, learns
incrementally, and every executed action went through the gate pipeline.

## 4. Dependencies

```
T2 → T3 → T4 → T5 → T6 → T8 → T9
          T7 (parallel with T4–T6)
T8 → T10 → T11 → T12
T4 + T8 + T11 → T13 → T14 → T15 (T16 parallel)
```

## 5. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Google Maps UI drift breaks the graph | Incremental learning (Phase 4) + tolerant state matching (stable ids/bounds, ignore volatile ETA text) + frozen emulator snapshot for evals |
| uiautomator dump variance (times, delays) | State matching on resource-ids/bounds; ignore text nodes marked volatile |
| Python↔Kotlin parity drift | Shared golden fixtures + CI parity test (T4) |
| SLM quality too low to be useful | Acceptance criteria in the ADR (T7); heuristic baseline; fall back to teacher-only and tune the threshold instead of forcing SLM |
| LAN model not always available | ADR-0019 tier fallback chain (LAN → cloud small → teacher) with honest state display |
| Learning bad rules (e.g., overfitting a flaky run) | Promotion threshold k + provenance/evidence counts; manual review for promoted rules; never auto-promote payment-classified actions |
| Payment gate erosion | Golden rule: the anchor engine is a *decider*, never an executor; all execution stays in the gate pipeline; benchmarks assert the gate still blocks |

## 6. Effort summary

| Phase | Days |
|-------|-----:|
| 1 — Use case + graph | 2 |
| 2 — Engine port + real evaluation | 4.5–5 |
| 3 — SLM fallback | 3.5–4.5 |
| 4 — Incremental learning | 3–4 |
| 5 — Embedding + benchmarks + docs | 5 |
| **Total** | **~18–20 days (~4 weeks)** |

## 7. Open decisions (need owner input)

1. **Engine home** — recommended: Kotlin slice in `services/brain` (per brain
   README contract statement), Python demo kept as the reference/executable
   spec. Alternative: keep a Python service.
2. **Evaluation target** — recommended: Android emulator via bridge/adb
   (existing `map_tree.xml` + ADR-0017). Confirm an emulator is available for
   T5/T9 (CI or local).
3. **SLM default** — recommended: Tier 1 LAN (Ollama small model) with
   Tier 2 small-cloud fallback; confirm whether T7 should spike a specific
   model list.
4. **Demo file placement** — **decided**: all anchor artifacts (demo, data,
   converter, this plan) live in `anchor/` inside the repo; production data
   will still live under `services/brain/knowledge` / `services/evals` when
   the Kotlin engine lands (T4).
5. **Timeline** — ~4 weeks solo OK, and milestone mapping G1–G4 as above?
