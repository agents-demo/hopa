# Windows sidecar protocol v1

The .NET host and the Kotlin engine talk in **newline-delimited JSON** over the
sidecar's **stdout** (sidecar -> host) and **stdin** (host -> sidecar). Stderr is
free-form logging and never carries protocol messages.

Version: `1` (the `ready` message carries it). Breaking changes bump the number
and update this file in the same commit. P0 froze this document; P1 implements
`step`, P4 implements the `task.*` view plus `gateway.state`, and W8 adds the
memory/skill families as additive v1 messages.

## Messages

### host -> sidecar

| type | fields | meaning |
|---|---|---|
| `hello` | - | optional; the sidecar answers `ready` anyway at start |
| `turn.start` | `id`, `goal`, `conversationId?`, `attachment?`, `planApproved?` | run one turn for this goal in that conversation (a blank id creates one); `planApproved` skips the plan gate |
| `turn.cancel` | - | stop the running turn at the next safe point |
| `configure` | `bridgeUrl`, `useBridge`, `bridgeToken`, `bridgeRefresh`, `modelProvider`, `modelBaseUrl`, `modelName`, `modelKey`, `tone`, `profile`, `replay`, `planFirst`, `vision` | settings in memory; secrets are never written to disk here |
| `gateway.state` | `paired`, `phoneOnline` | P4: whether this PC has a gateway credential and a phone peer; a phone approval is only accepted while both are true |
| `device.result` | `id`, `ok`, `error?`, `observation?`, `app?` | the host performed, or refused, a requested device action |
| `approval.result` | `id`, `allow`, `device?` | the answer to one `approval.request`; `device` is `pc` or `phone` and is checked against the live gateway link |
| `file.attach` | `id`, `path` | copy a file into the sidecar's attachment directory |
| `file.remove` | `id`, `path` | drop a pending attachment |
| `memory.list` | `id` | list the remembered facts |
| `memory.add` | `id`, `text` | remember one fact; replies with the new list |
| `memory.delete` | `id`, `text` | forget one fact; replies with the new list |
| `memory.clear` | `id` | forget all facts; replies with the new list |
| `skills.list` | `id` | list trigger → action pairs |
| `skills.add` | `id`, `trigger`, `action` | teach one pair; replies with the new list |
| `skills.delete` | `id`, `trigger` | forget one trigger; replies with the new list |
| `skills.clear` | `id` | forget all skills; replies with the new list |
| `history.list` | `id` | finished turns, flattened for the history screen |
| `usage.summary` | `id` | counters computed from the record chain |
| `recipes.list` | `id` | saved repetitions |
| `recipes.delete` | `id`, `goal` | forget one repetition; replies with the new list |
| `recipes.clear` | `id` | forget all repetitions; replies with the new list |
| `profiles.list` | `id` | the shared profile catalogue and the selected key |
| `profiles.select` | `id`, `profile` | choose a shell; replies with the catalogue and selection |
| `capabilities.summary` | `id` | live platform, profile, model, bridge, gateway and store counts |
| `conversations.list` | `id`, `includeArchived?` | list conversations |
| `conversation.create` | `id` | create an empty conversation |
| `conversation.open` | `id`, `conversationId` | read one conversation |
| `conversation.rename` | `id`, `conversationId`, `title` | rename |
| `conversation.pin` | `id`, `conversationId`, `pinned` | pin or unpin |
| `conversation.archive` | `id`, `conversationId`, `archived` | archive or restore |
| `conversation.delete` | `id`, `conversationId` | tombstone a conversation |
| `conversation.export` | `id`, `conversationId` | export one conversation as JSON |
| `conversation.search` | `id`, `query` | search titles and messages |
| `task.start` | `id` (request), `taskId?`, `goal`, `device?` | create a local task view (P4); the backend assigns the real task id, and the reply's id is generated when `taskId` is blank |
| `task.list` | `id` | list task views (P4) |
| `task.get` | `id`, `taskId` | read one task view (P4) |
| `task.handoff` | `id`, `taskId`, `target` | record the gateway target; the host sends `task.create` to the backend (P4) |
| `task.event` | `id`, `taskId`, `event`, `from`, `at?`, `platform?`, `error?` | apply a gateway task event; `event` is the gateway type (`task.ack` …), `from` is server-set and `platform` maps to the approver label |
| `shutdown` | - | the host is closing; the sidecar exits |

### sidecar -> host

| type | fields | meaning |
|---|---|---|
| `ready` | `version` | the loop is loaded and can take a turn |
| `configured` | `id`, `bridge`, `model` | settings accepted; the summary carries no secrets |
| `log` | `text` | a human-readable line for the host's log |
| `step` | `id` (turn), `index`, `action`, `classification`, `tier`, `approved`, `executed`, `verified`, `error?`, `at`, `durationMs` | one action finished; the rail can fill live |
| `device.request` | `id`, `op`, plus op fields | perform one device action on the host |
| `approval.request` | `id`, `title`, `body`, `amount`, `merchant`, `consequence`, `isPayment`, `action` | ask the person |
| `session` | `token`, `refresh` | the sidecar rotated the bridge pair; the host persists it |
| `turn.end` | `id`, `conversationId`, `title`, `answer`, `steps[]`, `chainOk`, `plan[]` | the turn finished; `plan` is the steps waiting for approval on a plan-first turn |
| `conversation.*` | echo `id` plus the payload | replies to the conversation messages above |
| `memory.list` | `id`, `ok`, `items:[string]` | the memory facts; also the reply to add/delete/clear |
| `skills.list` | `id`, `ok`, `items:[{trigger, action}]` | the learned pairs; also the reply to add/delete/clear |
| `memory.error` / `skills.error` | `id`, `ok:false`, `code`, `error` | a malformed or unsupported memory/skill request |
| `history.list` | `id`, `ok`, `items:[{conversationId,title,runId,createdAt,steps,executed,failed}]` | finished turns |
| `usage.summary` | `id`, `ok`, `total`, `executed`, `failed`, `payments`, `lastSevenDays`, `topActions:[{kind,count}]` | usage counters |
| `recipes.list` | `id`, `ok`, `items:[{goal,app,steps,at,replayable,screenHash,endHash}]` | saved repetitions; also the reply to delete/clear |
| `history.error` / `usage.error` / `recipes.error` | `id`, `ok:false`, `code`, `error` | a refused read or mutation |
| `profiles.list` | `id`, `ok`, `selected`, `items:[{key,label}]` | the shared profile catalogue |
| `profiles.error` | `id`, `ok:false`, `code`, `error` | an unknown profile |
| `capabilities.summary` | `id`, `ok`, `platform`, `profile`, `model*`, `bridge`, `gateway*`, `memory`, `skills`, `recipes`, `runs`, `windowsApps` | the live capability probe |
| `file.attached` | `id`, `attachment?`, `error?` | the attachment was accepted or refused |
| `file.removed` | `id`, `ok` | the pending attachment was dropped |
| `task.*` | echo `id` plus the task payload | replies to the task messages above |
| `task.error` | `id`, `ok:false`, `code`, `error` | a task message was refused (a bad request in P4) |

## Device operations in v1

| op | fields | host does |
|---|---|---|
| `observe` | - | returns a UI Automation tree and an observation |
| `tap` | `ref?`, `x?`, `y?` | pattern first, then a click |
| `doubleTap` | `ref?`, `x?`, `y?` | two presses |
| `longPress` | `ref?`, `x?`, `y?` | one held press |
| `type` | `text`, `ref` | `ValuePattern`, then the keyboard; **ref required** |
| `swipe` | `fromX`, `fromY`, `toX`, `toY` | a drag |
| `key` | `key` (`back` or `home`) | Escape or show-desktop |
| `launch` | `app` | launch and prove the foreground |
| `foreground` | - | the foreground process name |
| `openLink` | `url` | open an http/https/ms-settings URI and report the foreground |
| `screenshot` | - | `image` (base64 PNG) or no frame for a protected window |
| `stop` | `app` | ask the window to close; a save prompt is reported, never killed |
| `apps` | - | the Start-menu list: `[{package, label}]` |

A `device.result` carries `ok`, and on success any of `observation`, `app`,
`text` (which path an action took), `image` (base64 PNG) or `apps`
(`[{package, label}]`). An unimplemented op must answer `ok: false` with an
`error` the user can read; silence is a bug.

## Memory and skills

The sidecar stores memory facts in `memory.json` and trigger → action pairs in
`skills.json` under the data directory. Both implement the same
`com.hopa.stores` contracts as Android, and their prompt text is identical. A
turn passes the current text in `TurnContext.memory` and `TurnContext.skills`;
the host never needs to resend them. Facts and triggers are user content: log
counts, not their text.

`history.list` and `usage.summary` are projections over `records.json`;
`recipes.list` reads the shared `RecipeStore`. All three are read-only except
the recipe delete/clear commands. None of them writes a second copy of the data.

## Approval rules

- `approval.request` is sent only when the real `ApprovalPolicy` says the action
  needs one. The host cannot pre-approve, batch or remember a decision.
- A missing, late or malformed `approval.result` counts as **deny**.
- The sidecar waits at most **120 s**; then the action is denied and recorded
  with `executed: false`.
- A payment is denied unless the person answers this exact request. No token,
  flag or environment variable changes that.

## Task shapes (P4)

`task.list` -> `{"type":"task.list","id":"…","ok":true,"tasks":[{"id":"t-1","state":"queued",…}]}`

`task.needs_approval` creates a task in `needs_approval` with
`{goal, approval:{title, body, amount, merchant, consequence, isPayment, action}}`.
The target answers with `task.result` carrying `{approval:{allow}}`.

`task.start`, `task.get`, `task.handoff` and `task.event` share the task object
below. P4 implements a **local view of a backend gateway task**
(ADR-0024). States and event names are the gateway's, from ADR-0022 and
`contracts/schemas/gateway.v1.schema.json` — this is not a second state machine:

```json
{"id":"t-1","state":"queued|delivered|acked|progress|needs_approval|done|failed|cancelled",
 "from":"pc","to":"phone",
 "events":[{"index":0,"type":"task.create|task.needs_approval|deliver|task.ack|task.progress|task.result|task.error|task.cancel","from":"pc","at":0}],
 "postconditions":["…"],"approver":{"device":"pc|phone","at":0}}
```

`task.start` creates a view in `queued`. `task.handoff` records the target; the
host sends `task.create` to the gateway, and the sidecar learns of delivery
through `task.event`. `task.event` applies one gateway event and moves the state
exactly as `TaskRouter` does. `task.get` returns the view; `task.list` returns
the array. `from` is the server-set device id mapped to `pc`/`phone`; a client
cannot name another device. An `approver` on a result comes from the gateway
`platform` (`windows -> pc`, `android -> phone`) and the authenticated sender —
an `allow` that claims the phone but arrived from the PC side is refused. P4
also carries `task.needs_approval` as its own state: the host sends the approval
request on the gateway, the phone answers with `task.result` containing
`{approval:{allow}}`, and the sidecar records `approver.device` from the answer
source. A host with no live phone link gets a local sheet and never claims a
phone approval.

## Rules

- One message per line, UTF-8, no pretty printing.
- `id` is unique per request. The sidecar waits at most **20 s** for a
  `device.result`, then the action fails with a device error.
- The host waits at most **120 s** for a `turn.end`.
- A `turn.end` without a matching `turn.start` is ignored and logged.
- The sidecar never writes logs to stdout; a stray `println` breaks the stream.
- No secrets travel after `configure`: `session` carries tokens because it is the
  rotation the host must persist, and it is never logged.
- `step` is additive. A host that ignores it still behaves correctly.

## Example

```
host -> {"type":"hello"}
sidecar -> {"type":"ready","version":1}
host -> {"type":"turn.start","id":"g-1","goal":"click the notepad text area"}
sidecar -> {"type":"step","id":"g-1","index":0,"action":"ui.tap","classification":"read","approved":null,"executed":true,"verified":true,"error":null,"at":1763000000000,"durationMs":41}
sidecar -> {"type":"turn.end","id":"g-1","conversationId":"c-1","title":"click the notepad text area","answer":"Done.","steps":[…],"chainOk":true}
host -> {"type":"shutdown"}
```
