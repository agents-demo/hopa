# core - the client engine

Ten Kotlin modules the Android app and the Windows sidecar both build. Plain
JVM: no UI, no Android SDK, no `main`.

Modules are listed **bottom first, by dependency**. A module only uses the ones
above it; inside one layer the order is alphabetical.

## Layer 0 - the vocabulary

| module | what it holds | depends on |
|---|---|---|
| `contracts` | wire types (`Action`, `Observation`, `RunRecord`, `Decision`), ports (`DevicePort`, `ModelPort`, `Clock`, `ApprovalGateway`), `TurnContext`/`TurnResult`, `ObservationHasher`, JSON helpers | nothing |

## Layer 1 - leaves on top of contracts

| module | what it holds | depends on |
|---|---|---|
| `backend` | the backend link: task delivery, pairing, envelope codec, the knowledge fetch | `contracts` |
| `bridge` | the PC companion link: websocket client, sessions, `AdbDevice`, observation over the bridge | `contracts` |
| `catalog` | what apps and sites exist, what needs approval, how HOPA should speak, and the router that picks an app for a goal. Mostly generated. | `contracts` |
| `decision` | decision layers (rules, hand graph, LAIX), the coordinator/selector, and the comparison/conformance corpus | `contracts` |
| `inference` | model adapters: the OpenAI-compatible client, the demo client, and later a local runtime | `contracts` |
| `observation` | the screen as a tree with anchors: `ObservationProducer`, `NodeAnchor`, `ScreenPath`, `ScreenSource` | `contracts` |
| `runlog` | the run journal: build a record per step, chain it, hand it to a recorder | `contracts` |
| `runtime` | `RunGate`, `RunState`, `RunSource`: who owns the phone for the current run | nothing |

These eight do not import each other. A model API change never touches the bridge;
a bridge change never touches a record.

## Layer 2 - the engine

| module | what it holds | depends on |
|---|---|---|
| `agent` | the turn (`TurnRunner`), the loop (`AgentLoop`), the gate (`ApprovalPolicy`), the executor, the prompt, recipes, and the decision seam | `contracts`, `catalog`, `decision`, `observation`, `runlog` |

`agent` does not import `inference`: it asks a `DecisionPolicy`, and the client
passes a model-backed one. That is what lets the model be swapped or removed.

## Rules

1. `contracts` holds types and pure helpers. No behaviour that reaches out.
2. No Android and no HTTP in the engine. Only `bridge`, `backend` and
   `inference` open a socket.
3. One public class per file, named after it. Contracts may share a file;
   behaviour never does.
4. `catalog` is generated: edit `spec/`, run `tools/scripts/build-*.py`, commit.
   It has no ktlint, because reformatting generated output breaks `--check`.
5. The gate is in `agent`. Every action goes through `ActionExecutor`, so a
   model, a recipe and a graph all hit the same approval check.

## Where a decision comes from

The word appears in three places:

- `contracts.Decision` (Layer 0) is the wire data of one step.
- `decision` (Layer 1) is the scored decision machinery: `DecisionLayer`, the rules/graph/LAIX layers, the coordinator/selector, and the comparison/conformance corpus.
- `agent.decision` (Layer 2) is the loop's seam: `DecisionPolicy`, the concrete policies, and `DecisionRuntime`, which connects the core coordinator to the loop.

`AgentLoop` asks a `DecisionPolicy` for one `Decision` per step and never learns
who answered:

| policy | what it does |
|---|---|
| `ModelDecisionPolicy` | builds the prompt, asks the provider, parses the reply |
| `GraphDecisionPolicy` | takes the best guarded edge from the screen it recognizes |
| `FallbackDecisionPolicy` | tries the graph, asks the model when there is no path |
| `ChainDecisionPolicy` | tries each policy in the order the client supplies; first non-`NoPath` wins |
| `RecipeDecisionPolicy` | replays a recipe that worked before |

Prompt building and parsing live only in `ModelDecisionPolicy`, so a policy that
never calls a model does not build a prompt and does not need `inference`.

## Commands

```
./gradlew :contracts:check \
          :backend:check :bridge:check :catalog:check :decision:check \
          :inference:check :observation:check :runlog:check :runtime:check \
          :agent:check :agent:ktlintCheck \
          :backend:test :bridge:test :catalog:test :decision:test \
          :inference:test :observation:test :runlog:test :runtime:test \
          :agent:test
```

`agent` also runs `com.hopa.agent.conformance`, which validates decisions and
records against `spec/`.
