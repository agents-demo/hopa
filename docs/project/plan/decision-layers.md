# Decision layers

Status: D1-D7 done except the device run (2026-11-21); see `decision-results.md`

HOPA will use **several decision layers**, not one. LAIX is the first to try, a
rules layer is the baseline, a small intent classifier may follow, and a
model-as-judge layer exists to compare against. The loop must not know which
one answered.

This document is the plan for that: the contract, the registry, how a layer is
chosen, how layers are compared, and how one is promoted or removed.

## Why a layer at all

Today the step after a plan is decided by the model's prose and the approval
policy. A decision layer makes that explicit: act, wait, ask, verify or
escalate, with a reason code, a confidence and a trace. For a closed set of
commands (open an app, toggle a setting, read the screen) a layer plus a small
intent classifier can skip the model entirely: milliseconds instead of minutes,
and a trail a person can read.

LAIX is exactly this shape - training-free, stateless, with reason codes,
commitments and an audit trail - and it ships a Kotlin/JVM implementation
(`packages/kotlin/laix`, Apache-2.0, 0.18 pre-1.0).

## The contract is ours

```kotlin
interface DecisionLayer {
    val metadata: LayerMetadata
    suspend fun decide(context: DecisionContext): LayerDecision
}

data class LayerMetadata(
    val id: String,
    val version: String,
    val latency: LatencyClass,      // MICRO | MILLI | SECONDS
    val decidesUpTo: ActionClass,   // READ | CHANGE | DANGEROUS
    val status: LayerStatus,        // EXPERIMENTAL | SHADOW | DEFAULT | RETIRED
    val conformance: ConformanceStatus, // NOT_RUN | PASSED | FAILED
    val author: String,
    val summary: String,
)

data class DecisionContext(
    val runId: String,
    val step: Int,
    val action: Action?,            // what is about to happen
    val screen: String,             // the current screen summary
    val history: List<String>,      // action signatures already taken
    val approvals: List<String>,    // signatures a person already allowed
    val attention: AttentionBudget, // how much interruption is left
    val cancelled: Boolean,
    val atStepLimit: Boolean,
)

data class LayerDecision(
    val verb: Verb,                // ACT | WAIT | ASK | VERIFY | ESCALATE
    val reason: String,            // a stable code, never prose
    val confidence: Double,        // 0..1
    val trace: String,             // one line for the run log
)
```

The output is `LayerDecision`, not `Decision`: `com.hopa.contracts.wire.Decision`
is already the model's wire answer (say / done / needUser), and two types with
one name in one loop is how a bug is born.

No vendor type crosses this boundary. LAIX, rules, a classifier or a model
judge are all adapters behind it, so a pre-1.0 API cannot leak into the loop.

## Registry and metadata

Every layer registers with:

| Field | Why |
|---|---|
| `id`, `version` | the run log must name what decided |
| `latency` | `MICRO` / `MILLI` / `SECONDS` - a phone cannot wait for the last one per step |
| `decidesUpTo` | the strongest action class it may decide alone |
| `status` | `EXPERIMENTAL` / `SHADOW` / `DEFAULT` / `RETIRED` |
| `conformance` | `NOT_RUN` / `PASSED` / `FAILED`; only `PASSED` layers may decide |
| `author`, `summary` | who to ask when it misbehaves, and what it is good at |

The registry lists layers; it does not decide which one runs. It refuses a
duplicate id at construction, so a misconfigured build fails in a test rather
than on a phone.

## Choosing a layer is policy, not a winner-take-all

A single global "best layer" is wrong: the class of action decides.

| Action class | Wire actions | Allowed layers |
|---|---|---|
| `READ` | `ui.observe`, `ui.back`, `ui.home`, `ui.launch`, `ui.scroll`, `ui.wait`, `ui.stop`, `web.read` | layers whose `decidesUpTo` is at least `READ` |
| `CHANGE` | taps, typing, swipes, app functions, navigation and calls | layers whose `decidesUpTo` is at least `CHANGE` |
| `DANGEROUS` | payments, delete, uninstall, reset, **and every unknown kind** | layers that cover `DANGEROUS` and passed conformance; the person still approves |

Under `Automatic`, the first `DEFAULT` layer allowed for the class is applied.
A pinned layer that cannot cover the class, is retired or has not passed
conformance is skipped with a notice, and `Automatic` decides instead. The
`requiresApproval` flag stays true for `DANGEROUS` whatever is selected.

The policy lives in `core/decision` (`:decision`) and is configuration, not code
in the loop.

## Conformance kit

A layer may not enter `safe` or `dangerous` decisions until it passes:

- an empty or unknown action never yields `ACT`;
- a refusal is `ASK`, not `ACT`;
- a repeat of the same step is `VERIFY` or `WAIT`, not `ACT` again;
- a cancelled turn never produces a later `ACT`;
- the trace names the reason code the layer returned.

The kit is a plain JVM test suite; every adapter runs it.

## Comparison harness

- `spec/decisions/` holds a versioned corpus: 10-20 scenarios with the decision
  a careful person would make, the class of action and the allowed verbs.
- The runner takes **any** registered layer and reports: agreement with the
  corpus, latency p50/p95, confidence calibration, trace completeness.
- One report lists every layer side by side. CI runs the runner on changed
  layers; the full table is produced before a promotion.
- Same harness for "no layer" (today's path) so the comparison is honest.

## Shadow mode

Every active layer votes on real turns; only the selected layer is applied.
All votes land in the run log as `decision.vote` records (layer id, verb,
reason, confidence, whether it was applied). Nothing is blocked.

In the app the votes go to the `decision_votes` table (`DecisionVoteEntity`):
run id, step, layer id and version, action kind and class, the mode that was in
force, verb, reason, confidence, trace, latency, `applied`, an error for a layer
that threw, the selector's notice, and the time. The table keeps the latest
5 000 rows. A failing sink never stops a turn.

Shadow recording is on when `shadowDecisions` is true, whatever the mode. In
that state the applied layer's vote is also written, so a later comparison can
tell "applied and right" from "would have been better".

This is how "which one works best" becomes data: after a week the run log shows
where LAIX disagrees with the rules, where it is over-confident, and where the
model path was the only correct answer.

## Lifecycle of a layer

1. **Experimental**: module + adapter + conformance kit. Not registered for real
   traffic.
2. **Shadow**: registered, votes, never applies.
3. **Default / allowed for a class**: promotion requires a table that beats the
   current choice on task success and latency with **no** growth in dangerous
   mistakes.
4. **Retired**: removed from the registry and the build. A layer that loses in
   its class is deleted, not kept "for choice" - the repository must not become
   a zoo of dead adapters.

## How LAIX reaches the build

| Option | When | Why |
|---|---|---|
| Included build (`includeBuild("../../laix/packages/kotlin/laix")`) | local experiment only | zero ceremony, but depends on a path outside the repo |
| **Vendored sources** with a pinned commit and the Apache-2.0 notice | merging into `main` | reproducible, offline, no surprise upgrades |
| Published artifact (JitPack tag or Maven) | later, if LAIX stabilises | a real dependency, but a pre-1.0 API in CI is a risk |

Decision: included build for the spike, vendored sources for anything merged.
No `latest`, no SNAPSHOT.

Done in D4: the vendored copy is a subset (the action policy, its contracts and
three support files) at a pinned commit, with the Apache-2.0 text beside it, an
entry in the root `NOTICE`, and `core/decision/LAIX.md` describing the
provenance and the update procedure. The structure check skips that directory
on purpose; `ktlint` does too.

## In the build now (D1-D7)

| Where | What |
|---|---|
| `core/decision` (`:decision`) | `DecisionLayer`, `LayerMetadata`, `DecisionContext`, `LayerDecision`, `DecisionRegistry`, `DecisionSelector`, `DecisionCoordinator`, `DecisionVote`, `ConformanceKit`, `ComparisonHarness`; `RulesDecisionLayer`; the LAIX 0.18 action policy vendored at a pinned commit with `LaixDecisionLayer` as its only importer of `dev.laix.*`; `IntentClassifier`; the hand-written Settings/Clock/Camera graphs; the `decisionReport` task and the one list of shipped layers |
| `core/agent/.../TurnRunner` | runs a recognized command before the model; a miss falls through unchanged |
| `core/agent/.../AgentLoop` | applies the selected layer to `READ` steps: ACT proceeds, VERIFY re-reads, WAIT/ASK/ESCALATE stop the step |
| `apps/android/stores` | `AppSettings.instantCommands` (on by default) |
| `apps/android/feature/execution` | the `Decisions` page, reached from **How HOPA acts → Who chooses**: Off / Automatic / a layer, shadow, instant commands, and what is active per class |
| `core/agent` | `DecisionRuntime`: the loop's one way to ask, with mode and shadow as suppliers |
| `core/agent/.../AgentLoop` | calls the runtime after the model's action is parsed; the vote is data, the action still runs |
| `apps/android/data` | `decision_votes` table (schema 9), `DbDecisionVoteSink` |
| `apps/android/stores` | `AppSettings.decisionMode` (`off` by default) and `shadowDecisions` |
| `spec/decisions/corpus.v1.json` | 17 cases, each with a reference answer and the defensible answers |
| `spec/decisions/README.md` | the case format and the rules for adding one |
| `docs/project/plan/decision-results.md` | the measured table, the ten-task protocol, the promotion rule |

Commands, from `apps/android`:

```
gradlew :decision:test
gradlew :decision:decisionReport             # the comparison table
```

Both shipped layers match all 17 reference answers, make no dangerous `ACT`,
and pass the conformance kit. LAIX is registered as `SHADOW`: it votes on real
steps and is never applied until D6 gives it a class. The app behaves exactly
as before D1 apart from the recorded votes.

## Ready for a graph

The contract already separates **where the options come from** from **who chooses**:

```kotlin
data class ActionCandidate(val id: String, val action: Action, val failures: Int = 0)
data class DecisionContext(..., val goal: String, val planStep: String, val candidates: List<ActionCandidate>)
data class LayerDecision(..., val chosen: String? = null)
```

- The model path passes one candidate (`proposed`, the action the model chose),
  so the layers behave exactly as before.
- A navigation graph passes its outgoing edges; a layer returns `chosen` with
  the edge it picked.
- `Rules` ignores edges that failed twice, never picks a dangerous one, acts
  when exactly one safe read remains, and asks when several are plausible.
- `LAIX` builds one ACT option per edge and returns LAIX's own `actionId`; the
  adapter maps it back to `chosen`.
- `failures` is the hook for graph statistics; nothing fills it yet.

A first graph source exists in `core/decision` (`:decision`): three
hand-written apps (Settings, Clock, Camera), matched by package and visible text,
with a tap resolved from the control's label. A node counts only inside its own
app; an unknown screen inside a known app can have an `any` edge (Settings uses
it to step back to a page it knows). A miss on the screen, the control
or the goal returns null. **How HOPA acts -> Steps** chooses **Auto** (graph,
then model), **Model** (model only) or **Graph** (graphs only, unknown
goals refused); stored as `stepSource` in settings. The same section lists the
concrete **Known paths** per app from `graphs.v1.json`, and a graph answer keeps
its source in the chat receipt, so the claim survives the turn.

Still missing for a general graph: a node key in the context, learning edge
statistics from run records, a plan step per edge, and a screen to inspect or
delete learned edges. None of them require touching the loop again.

## Stages

### D1 - the port and the registry (1 PR) - done

`:decision` (the plan said `:core:decision`): `DecisionLayer`, `DecisionContext`,
`LayerDecision`, the registry, the class policy, the coordinator and tests.
Nothing is wired into the loop.

### D2 - the rules layer and the harness (1 PR) - done

`:decision` (`com.hopa.decision.rules`): heuristics for the known commands (the
fallback when no other layer is available). The corpus in `spec/decisions/` and
the runner that prints the comparison table for any layer.

### D3 - shadow logging (1 PR) - done

The loop calls the registry in shadow mode and writes `decision.vote` into the
run log. Behaviour unchanged, data starts flowing. `DecisionRuntime` is wired
into `TurnRunner`; `AgentLoop` evaluates every parsed action; `DbDecisionVoteSink`
writes the rows. A setting of `decisionMode = auto` with `shadowDecisions = true`
now produces one row per step per layer.

### D4 - LAIX adapter (1 PR) - done

Vendored `:decision` (`core/decision`, `dev/laix/`) at
`3ccc8add90dbd019197a990393600bbe1c1647d7`, the mapping from
`Action`/`ApprovalRequest` to LAIX's request and back, the conformance kit, and
its row in the comparison table. Only the action policy and the shapes it
returns are copied; `LAIX.md` lists the files and the update rules. The adapter
never offers `ACT` for a payment or a delete: those are `ASK` by construction.

### D5 - intent classifier for closed commands (1 PR) - done

15-20 canonical commands, a small JVM classifier with a confidence threshold,
and a path that skips the model when the intent is clear. Falls back to the
model otherwise.

The closed set is launch (any installed app, matched by label or package),
back, home, scroll up/down and wait. It is not a `DecisionLayer`: it replaces
the whole turn, not one step, so it lives in `TurnRunner` as a path before the
plan gate and the model: asking a model for steps to "open settings" is slower
and less predictable than opening it. A hit produces `TurnSource.COMMAND`, one
run record, no tokens and a
plain answer; a miss, an unknown app, an ambiguous label, an unreadable screen
or a thrown step all fall through to the model. `instantCommands` turns the
path off. Taps, typing and anything that changes a setting are deliberately not
classified: those need the screen the model reads.

### D6 - enable for safe actions (1 PR) - done

The class policy enforces decisions for `ui.launch`, `ui.read` and navigation.
Payments, delete, reset and uninstall keep the current approval policy, which
is not replaced by a layer.

`DecisionRuntime.appliesTo` is true only for `ActionClass.READ` and only when
the mode is not Off. The loop then: ACT proceeds; VERIFY re-reads the screen,
adds it to the prompt and skips the step; WAIT, ASK and ESCALATE end the step
with the layer's trace. `CHANGE` and `DANGEROUS` still vote (shadow or pinned)
but never change what runs. How HOPA acts -> Who chooses writes `decisionMode`,
`shadowDecisions` and `instantCommands`, shows each layer's status and latency,
and names the layer active for read, change and dangerous actions. A pinned
layer that has been retired, does not cover the class or failed conformance is
not used; the page shows what Automatic chose instead.

### D7 - measurement and the go/no-go (1 PR) - harness and protocol done

Ten tasks across three modes: model-only, shadow, decisions-on. Metrics: task
success, p50/p95 latency, model calls, false refusals, trace completeness. The
result decides whether the command set grows or the layer stays an audit trail.

`decision-results.md` holds the current corpus table (both layers 17/17, zero
dangerous `ACT`), the exact ten-task protocol, the five promotion conditions and
the current decision: rules is the fallback, LAIX stays shadow, automatic stays
opt-in. The device half needs the phone and the model-only capture.

## Choosing where HOPA acts

The person decides whether layers are used at all, and which one. The choice
belongs with the act screens, not with the model or the chat: **How HOPA acts ->
Who chooses -> Change** opens the Decisions page. Settings no longer lists it.

```
Decisions
  (o) Off - the model decides, as today
  ( ) Automatic - the best allowed layer for each action
  ( ) Rules - heuristics for known commands
  ( ) LAIX - live decision policy

  Recording
  [x] Record what other layers would decide (shadow)
  [x] Instant commands - open, back, home, scroll and wait skip the model

  Active now
  Reading the screen      Rules
  Changing a setting      Model
  Payments and deletes    Model
```

- **Off** is the honest default until a layer beats the model on the corpus. The
  model path stays exactly as it is.
- **Automatic** applies the class policy in `:decision`; the page shows which
  layer that means for reading, changing and dangerous actions.
- **A specific layer** pins it wherever it is allowed; a layer that does not
  cover an action class is skipped there, Automatic decides, and the page's
  "Active now" rows say so. In this build a layer is applied to `READ` steps
  only; `CHANGE` and `DANGEROUS` still take the model path.
- **Shadow** can be on in any mode: votes are logged, nothing changes.
- Each row shows the layer's status badge (`default`, `shadow`, `experimental`),
  its latency class and one line of what it is good at - the same honesty the
  model page uses.
- Dangerous actions (payments, delete, reset, uninstall) always keep the
  approval step, whatever is selected.

Storage: `decisionMode`, `shadowDecisions` and `instantCommands` in
`AppSettings`; the mode is `off`, `auto` or a layer id. A layer that disappears from the
build leaves the setting pointing at nothing, and the page falls back to
Automatic with a notice instead of breaking.

## Acceptance criteria

1. Adding a layer touches no loop, UI or approval code - a new module plus a
   registry entry.
2. Every layer passes the conformance kit before it can decide a `safe` action.
3. The comparison table exists for at least three layers plus "no layer".
4. A promoted layer beats the previous choice on task success and latency with
   no increase in dangerous mistakes.
5. A retired layer leaves no dead module, flag or branch behind.
6. The run log names the layer, its version and its reason code for every turned
   decision.

## Risks

| Risk | Mitigation |
|---|---|
| LAIX is pre-1.0 | vendored pinned sources; our contract in front of it |
| Layer zoo | lifecycle rules; a loser is deleted |
| Over-confidence | calibration reported by the harness; `ASK` required below a threshold |
| Dangerous actions decided by a layer | class policy keeps approvals and forbids layers there |
| Two sources of truth | the loop consults only `DecisionLayer`; LAIX's own trace is stored as a field, not as the decision |
