# One turn, from a prompt to an answer

This page replaces the hand-drawn
[`docs/media/hopa-turn-flow.png`](../../media/hopa-turn-flow.png). It has two
pictures: the whole turn, with the loop as one box, and the loop itself.

A few words are used throughout:

- **written path** - a few hand-written steps for an app HOPA knows (Settings,
  Clock, Camera). It remembers where it is: the current screen is a node, and the
  things it can do next are the edges from that node.
- **model** - the AI that writes the next step or the answer. It is either
  **cloud** (an API call, like DeepSeek) or **local** (a file downloaded to this
  phone).
- **token** - what a model is paid by. `0 tokens` means no model was asked.

## 1. The whole turn

The loop is a single box here; the next picture opens it.

```mermaid
flowchart TD
  A(["The person writes a prompt"]) --> B{"Plan first?"}
  B -->|"yes"| C["Show the plan<br/>nothing runs yet"]
  C --> D{"Approved?"}
  D -->|"no"| Z1["Stop"]:::stop
  D -->|"yes"| E
  B -->|"no"| E
  E{"Can HOPA reach the apps?<br/>is a screen readable?"} -->|"no"| Z2["Say what is missing<br/>stop"]:::stop
  E -->|"yes"| F["Work on the chosen screen<br/>hidden display or your screen"]
  F --> G["The first step opens the app<br/>the goal needs, if any"]
  G --> L(["The loop<br/>one step at a time<br/>see the next picture"]):::loop
  L --> R(["Done"]):::answer

  classDef io fill:#EAF1FB,stroke:#5B7FD4,color:#1C2B4A,stroke-width:1.5px
  classDef core fill:#E7F4EA,stroke:#3F8F5A,color:#16301F,stroke-width:1.5px
  classDef loop fill:#FFF4D6,stroke:#C9962F,color:#3A2C08,stroke-width:2px
  classDef result fill:#E0F2F1,stroke:#2F7D7A,color:#0F2E2C,stroke-width:1.5px
  classDef stop fill:#FBE4E4,stroke:#BF5252,color:#3D1414,stroke-width:1.5px

  class A,F,G io
  class B,C,D,E core
  class R result
  class Z1,Z2 stop
```

## 2. The loop

One loop, two engines, one hand-over:

- while the current screen has a **written path**, the path decides the next
  edge at this node; if it has a confident edge, HOPA takes it and reads the
  screen again;
- if the path has **no edge** here (very low confidence), the rest of the turn
  is handed to the model;
- the model runs **in the cloud** or **on this phone**, and can answer, ask, or
  act.

```mermaid
flowchart TD
  IN(["From the turn<br/>the app is open, the screen is read"]) --> HAS{"Is there a written path<br/>for this app?"}
  HAS -->|"yes"| NODE{"At this node:<br/>which edge next?"}
  NODE -->|"a confident edge"| STEP["The path's next step"]
  STEP --> FIN{"Does it finish<br/>the goal?"}
  FIN -->|"no"| DO["Do it<br/>read the screen again"]
  DO --> NODE
  FIN -->|"yes"| END(["The turn ends<br/>the answer and its note"])
  NODE -->|"no edge here<br/>very low confidence"| WHICH{"Which model?"}
  HAS -->|"no"| WHICH
  WHICH -->|"cloud"| CLOUD["API call<br/>e.g. DeepSeek"]
  WHICH -->|"local"| LOCAL["A file on this phone"]
  CLOUD --> WHAT{"What came back?"}
  LOCAL --> WHAT
  WHAT -->|"a final answer"| END
  WHAT -->|"a question"| ASK["Show the question<br/>and wait for the person"]
  ASK -->|"the person answers"| WHICH
  WHAT -->|"an action"| ACT["Do it<br/>read the screen again"]
  ACT --> WHICH

  classDef io fill:#EAF1FB,stroke:#5B7FD4,color:#1C2B4A,stroke-width:1.5px
  classDef core fill:#E7F4EA,stroke:#3F8F5A,color:#16301F,stroke-width:1.5px
  classDef cloud fill:#E8F0FE,stroke:#3B6FD4,color:#15294D,stroke-width:1.5px
  classDef local fill:#E7F4EA,stroke:#3F8F5A,color:#16301F,stroke-width:1.5px
  classDef execute fill:#DDF3E4,stroke:#2F7D4F,color:#12301D,stroke-width:1.5px
  classDef answer fill:#E0F2F1,stroke:#2F7D7A,color:#0F2E2C,stroke-width:1.5px
  classDef question fill:#EAF1FB,stroke:#5B7FD4,color:#1C2B4A,stroke-width:1.5px,stroke-dasharray:5 3

  class IN,ASK io
  class HAS,NODE,FIN,WHICH,WHAT core
  class CLOUD cloud
  class LOCAL local
  class STEP,DO,ACT execute
  class END answer
```

## Two notes about the picture

**The decision at a node.** The picture says a decision is asked at the current
node. In today's code that decision is the written path's own matcher: it reads
the visible screen, matches the node, and looks for an edge whose words fit the
goal. The decision layers (Rules, LAIX) currently vote on the model's proposed
steps, not on graph edges. Letting a layer decide the graph edge is a code change
that has not been made; the picture shows the place where it would happen.

**Shortcuts left out on purpose.** Between the doorway and the loop there are two
fast paths that would crowd the picture:

- a **simple command** ("open", "back", "home", "scroll", "wait") is answered in
  one step, with no model;
- a **saved recipe** (steps that worked before for the same words) is replayed
  before the model is asked.

**Writing paths only.** If the person chose **Written paths only** on How HOPA
acts - Steps, there is no hand-over: an app or edge the path does not know ends
the turn with a note to switch to Auto or Model.

## What the person sees

| Where | What it says |
|---|---|
| While HOPA works | `Graph · Camera`, `Cloud · deepseek-v4-flash`, or the local model's name |
| Under the answer | `Graph · 2 steps · 2 confirmed · 0 tokens` |
| Tap the note | which screen was used, how long it took, and every step |
| Activity | the same steps, the usage and the runs, kept on the phone |

The note under the answer is saved with the message, so a written path still
looks like a written path months later. It appears only when at least one step
actually ran.

## Where this lives in the code

| Concern | Code |
|---|---|
| The doorway, the hand-over and the order | `core/agent/.../turn/TurnRunner.kt` |
| The model loop, the three outcomes | `core/agent/.../loop/AgentLoop.kt` |
| The written path: nodes, edges, the current screen | `core/decision/.../graph/` |
| Doing a step and the approval question | `core/agent/.../action/ActionExecutor.kt` |
| Cloud or local: the model choice | `core/inference/...`, `apps/android/app/.../di/AppContainer.kt` |
