# Windows sidecar protocol v1

The .NET host and the Kotlin engine talk in **newline-delimited JSON** over the
sidecar's **stdout** (sidecar -> host) and **stdin** (host -> sidecar). Stderr is
free-form logging and never carries protocol messages.

Version: `1` (the `ready` message carries it). Breaking changes bump the number
and update this file in the same commit. P0 froze this document; P1 implements
`step` and refuses `task.*` explicitly until P4.

## Messages

### host -> sidecar

| type | fields | meaning |
|---|---|---|
| `hello` | - | optional; the sidecar answers `ready` anyway at start |
| `turn.start` | `id`, `goal`, `conversationId?`, `attachment?` | run one turn for this goal in that conversation (a blank id creates one) |
| `turn.cancel` | - | stop the running turn at the next safe point |
| `configure` | `bridgeUrl`, `useBridge`, `bridgeToken`, `bridgeRefresh`, `modelProvider`, `modelBaseUrl`, `modelName`, `modelKey`, `tone` | settings in memory; secrets are never written to disk here |
| `device.result` | `id`, `ok`, `error?`, `observation?`, `app?` | the host performed, or refused, a requested device action |
| `approval.result` | `id`, `allow` | the answer to one `approval.request` |
| `file.attach` | `id`, `path` | copy a file into the sidecar's attachment directory |
| `file.remove` | `id`, `path` | drop a pending attachment |
| `conversations.list` | `id`, `includeArchived?` | list conversations |
| `conversation.create` | `id` | create an empty conversation |
| `conversation.open` | `id`, `conversationId` | read one conversation |
| `conversation.rename` | `id`, `conversationId`, `title` | rename |
| `conversation.pin` | `id`, `conversationId`, `pinned` | pin or unpin |
| `conversation.archive` | `id`, `conversationId`, `archived` | archive or restore |
| `conversation.delete` | `id`, `conversationId` | tombstone a conversation |
| `conversation.export` | `id`, `conversationId` | export one conversation as JSON |
| `conversation.search` | `id`, `query` | search titles and messages |
| `task.list` | `id` | list handoff tasks (refused in v1) |
| `task.get` | `id`, `taskId` | read one task (refused in v1) |
| `task.handoff` | `id`, `taskId`, `target` | move a task to another device (refused in v1) |
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
| `turn.end` | `id`, `conversationId`, `title`, `answer`, `steps[]`, `chainOk` | the turn finished; `answer` is what the user sees |
| `conversation.*` | echo `id` plus the payload | replies to the conversation messages above |
| `file.attached` | `id`, `attachment?`, `error?` | the attachment was accepted or refused |
| `file.removed` | `id`, `ok` | the pending attachment was dropped |
| `task.error` | `id`, `ok:false`, `code`, `error` | task messages are not available on this build |

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

## Approval rules

- `approval.request` is sent only when the real `ApprovalPolicy` says the action
  needs one. The host cannot pre-approve, batch or remember a decision.
- A missing, late or malformed `approval.result` counts as **deny**.
- The sidecar waits at most **120 s**; then the action is denied and recorded
  with `executed: false`.
- A payment is denied unless the person answers this exact request. No token,
  flag or environment variable changes that.

## Task shapes (frozen for P4, refused in v1)

`task.list` -> `{"type":"task.error","id":"…","ok":false,"code":"E_UNSUPPORTED","error":"task handoff is not implemented on this build"}`

The same envelope answers `task.get` and `task.handoff` in v1. P4 implements:

```json
{"id":"t-1","state":"waiting-approval|running|done|failed",
 "steps":[{"index":0,"device":"pc|phone","outcome":"succeeded|failed"}],
 "postconditions":["…"],"approver":{"device":"pc|phone","at":0}}
```

Until then, a host that asks for a handoff gets an explicit refusal, never a
silent success.

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
