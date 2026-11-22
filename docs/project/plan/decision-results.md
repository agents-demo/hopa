# Decision layers: results and the go/no-go

Status: D7 harness and protocol done (2026-11-21); device runs pending

This is the measurement half of `decision-layers.md`. It records what the two
shipped layers do on the corpus, how the ten-task comparison is run, and the
rule for promoting a layer. It is deliberately honest about what has not been
measured yet.

## What the harness measures

`gradlew :decision:decisionReport` (from `apps/android`) runs every layer
the build ships over `spec/decisions/corpus.v1.json` and prints:

- agreement with the reference answer;
- answers that were at least defensible (`allowed`);
- dangerous `ACT` (must be zero);
- latency p50/p95 over the cases;
- mean confidence and trace completeness;
- errors, with the failing case named.

The corpus has 17 cases: reads, writes, a payment, a delete, an uninstall, a
repeat, a refusal, no visible change, no attention left, a cancelled turn, an
unknown action and a step limit.

## Today's table (JVM, laptop, 2026-11-21)

| Layer | Version | Agreement | Allowed | Dangerous ACT | p50 | p95 | Mean confidence | Trace | Errors |
|---|---|---|---|---|---|---|---|---|---|
| rules | 1.0.0 | 100% (17/17) | 100% (17/17) | 0 | ~50 µs | ~34 ms | 0.85 | 100% | 0 |
| laix | 0.18.0 | 100% (17/17) | 100% (17/17) | 0 | ~1 ms | ~83 ms | 0.62 | 100% | 0 |

The p95 numbers are JVM warm-up on a laptop, not a phone: they say the rules
layer is microseconds and LAIX is around a millisecond, which is why both are
`MICRO`. They are not a device benchmark.

Conformance: both layers pass all eleven kit cases (empty action, unknown kind,
payment, delete, refusal, repeat, cancelled turn, step limit, spent attention,
read, launch).

There is no "model (recorded)" row yet. The corpus takes an optional `model`
verb per case; it is filled by capturing what the model-only path answered on a
device. Until then the comparison has no baseline, and the table says so by
omission rather than inventing numbers.

## What decisions change on the model path

The model (DeepSeek today, on-device tomorrow) still writes the plan and the
steps. A layer only decides whether the proposed step may run:

| Mode | What a layer does |
|---|---|
| `Off` | nothing; the model path is byte-for-byte the old one |
| `Off` + shadow | votes into `decision_votes`, never applies |
| `Automatic` | applies to `READ` steps only (observe, back, home, launch, scroll): act, verify, wait, ask or escalate |
| pinned (`rules`, `laix`) | the same `READ` application; on `CHANGE` and `DANGEROUS` it only votes |
| payments, delete, reset, uninstall | the layer never applies; the model and the approval gate decide |

A layer does **not** choose the action yet: that is the intent classifier's job
for the closed command set, and a later stage for the rest. Canonical commands
(open, back, home, scroll, wait) are the only turns that skip the model, and
`instantCommands` turns that path off. Decisions on the plan and on the whole
conversation are not implemented.

## Known-app graphs (v0)

A second path skips the model for a few apps written down by hand in
`core/decision`:

| App | What it can do |
|---|---|
| Settings | open, Connections, Wi-Fi, Bluetooth |
| Clock | open, Alarms, Timer |
| Camera | open |

Matching is literal: the current package and a visible string must identify the
node, the goal must contain one of the edge's words, and the control to tap must
be on screen. Anything else returns null. Every step goes through the normal
executor, so an approval or a failed tap stops it honestly.

The source is a first-class choice on **How HOPA acts -> Steps**:
**Auto** (a graph when the app is known, the model otherwise), **Model**
(model only, exactly as before) or **Graph** (graphs only; a goal they do
not cover is refused with a note to switch to Auto or Model, and neither a
command nor the model answers in their place). Under the segment,
the same page lists **Known paths**, built from `graphs.v1.json`, so a person can
see the concrete scenarios without opening a second screen.

A goal the graph can finish goes before an instant command: "open camera" is a
graph with an answer, so its receipt says Graph, not Command. A goal that
only opens an app ("open settings") stays with the command, because the graph has
no edge that finishes it.

A node is matched only inside its own app, and by an **exact** label: One UI's
root has no "Settings" title, so it is recognised by its category rows
(Connected devices, Notifications), while the Connections page is identified by
its items (Flight mode, Mobile networks, UWB), because Samsung does not expose
that page's heading. The screen is the node with the **most** matching labels, not
the first one found: the Connections page shows a Wi-Fi row before its other rows,
and a first-match rule would mistake it for the Wi-Fi screen. Exact matching is
what keeps a deep page titled "More connection settings" from passing as the
root. Settings also reopens on its last page, so the graph has a back edge from
any unknown Settings screen: it walks back to a screen it knows instead of giving
up or guessing.

The turn says its source twice: while it runs the status line names the path
("Graph - Camera"), and the receipt under the answer carries `source`, so a graph
answer reads "Graph - 1 step - 1 confirmed - 0 tokens" long after the turn. The
model's own label is used only when the model actually runs. Nothing is learned
or recorded yet.

## The ten-task protocol (needs a phone)

Run the same ten goals in three modes, twice each to catch flakes:

| Mode | Selection |
|---|---|
| model-only | `decisionMode = off`, `instantCommands = false` |
| shadow | `decisionMode = auto`, `shadowDecisions = true`, `instantCommands = false` |
| decisions-on | `decisionMode = auto`, `shadowDecisions = true`, `instantCommands = true` |

Tasks: open an app by name; open an app and read a named setting; go back twice;
scroll to a named item; wait for a screen to settle; a tap that needs approval; a
payment; a goal that needs a plan (two apps); an ambiguous command ("open
settings" when a bank app is also installed); a goal with a fake app name.

Metrics per task: success (did the goal hold), wall time, model calls, tokens,
number of approval prompts, false refusals, and whether the run log has a vote
for every step.

## Promotion rule

A layer (or the command path) becomes the default for a class only when:

1. it matches the current path on task success;
2. its p95 adds no more than 100 ms to the turn;
3. it produces **zero** dangerous `ACT` and zero missed approvals;
4. every step carries a trace with a reason code;
5. the comparison table in this file is updated with the new run.

Until all five hold, `decisionMode` stays `off` by default. `Automatic` is
available to try, and the Decisions page says what it will do.

## Current decision

- **rules** is the fallback and the reference; it may act on reads and asks for
  everything else.
- **LAIX** stays `SHADOW`: it is in every vote, it is measured, and it is not
  applied until the ten-task run gives it a class.
- **instant commands** run by default because they are deterministic and fall
  back to the model on any doubt; the ten-task run is what will show whether the
  fallback is honest in practice.
- **crash isolation** for the local engine and **device measurements** remain the
  blockers for an on-device promotion; see `on-device-model.md`.

## Next

1. Connect the phone, capture the model-only answers into `corpus.v1.json`.
2. Run the ten tasks in the three modes; write the table here.
3. Promote, keep as shadow, or retire each layer by the rule above.
