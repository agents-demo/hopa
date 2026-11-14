# Windows sidecar protocol v0

The .NET host and the Kotlin engine talk in **newline-delimited JSON** over the
sidecar's **stdout** (sidecar -> host) and **stdin** (host -> sidecar). Stderr is
free-form logging and never carries protocol messages.

Version: `1` (the `ready` message carries it). Breaking changes bump the number
and update this file in the same commit.

## Messages

### host -> sidecar

| type | fields | meaning |
|---|---|---|
| `hello` | - | optional; the sidecar answers `ready` anyway at start |
| `turn.start` | `id`, `goal`, `conversationId?` | run one turn for this goal, in that conversation (a blank id creates one) |
| `configure` | `bridgeUrl`, `useBridge`, `bridgeToken`, `modelProvider`, `modelBaseUrl`, `modelKey`, `tone` | the host pushes settings; secrets are held in memory only |
| `device.result` | `id`, `ok`, `error?` | the host performed the requested device action |
| `shutdown` | - | the host is closing; the sidecar exits |

### sidecar -> host

| type | fields | meaning |
|---|---|---|
| `ready` | `version` | the loop is loaded and the sidecar can take a turn |
| `configured` | `id`, `bridge`, `model` | settings were accepted; the summary carries no secrets |
| `log` | `text` | a human-readable line for the host's log |
| `device.request` | `id`, `op`, plus op fields | perform one device action on the host |
| `turn.end` | `id`, `answer` | the turn finished; `answer` is what the user sees |

### Device operations in v0

| op | fields | host does |
|---|---|---|
| `tap` | `x`, `y`, `ref?` | click at the point (W0: the Notepad text area) |
| `doubleTap` | `x`, `y`, `ref?` | not implemented in v0; the host refuses |
| `longPress` | `x`, `y`, `ref?` | not implemented in v0; the host refuses |
| `type` | `text`, `ref?` | not implemented in v0 |
| `swipe` | `fromX`, `fromY`, `toX`, `toY` | not implemented in v0 |
| `key` | `key` (`back` or `home`) | not implemented in v0 |
| `launch` | `app` | not implemented in v0 |

An unimplemented op must answer `device.result` with `ok: false` and an `error`
the user can read; silence is a bug.

## Rules

- One message per line, UTF-8, no pretty printing.
- `id` is unique per request; the sidecar waits at most **15 s** for a
  `device.result`, then the action fails with a device error.
- The host waits at most **60 s** for a `turn.end`.
- A `turn.end` without a matching `turn.start` is ignored and logged.
- The sidecar never writes logs to stdout; a stray `println` breaks the stream.
- No secrets travel in these messages after start: W2 will add a `set-model-key`
  message that carries the key once, in memory only.

## Example

```
host -> {"type":"hello"}
sidecar -> {"type":"ready","version":1}
host -> {"type":"turn.start","id":"g-1","goal":"click the notepad text area"}
sidecar -> {"type":"device.request","id":"req-1","op":"tap","x":700,"y":600}
host -> {"type":"device.result","id":"req-1","ok":true}
sidecar -> {"type":"turn.end","id":"g-1","answer":"Sidecar answered: ..."}
host -> {"type":"shutdown"}
```
