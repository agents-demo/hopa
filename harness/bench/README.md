# HOPA-Bench

A tiny, device-driven benchmark for HarmonyOS GUI agents. Tasks are data
(YAML or JSON); the runner uses `pc-agent` to observe and act on a real
emulator/device.

> The shipped `StubModel` replays each task's scripted `steps`. That exercises the
> whole harness without a network or an LLM. **Task success is evaluated against
> the device**, so a wrong script is reported as a failure. By default, `bench run`
> completes even when tasks fail (success is reported, not required).

## Task format

```yaml
schema_version: 1
id: settings-bluetooth
goal: "Open Settings and reach the Bluetooth screen"
app: Settings
bundle: com.huawei.hmos.settings        # optional; inferred from app
success:
  type: text_visible                    # text_visible | app_foreground | always
  any: ["Bluetooth", "Bluetooth settings"]
steps:                                  # optional scripted path (stub model)
  - action: launch
  - action: wait
    seconds: 2
  - action: tap_text
    text: Bluetooth
max_steps: 10
```

Required: `id`, `goal`, `app`, and a valid `success` check. `steps` are optional.

### Actions

| Action | Params |
| --- | --- |
| `launch` | `bundle?`, `ability?` |
| `tap` | `x`, `y` |
| `tap_text` | `text` (finds the node, taps its center) |
| `tap_id` | `id` |
| `type` | `text`, `x?`, `y?` |
| `swipe` | `from_x`, `from_y`, `to_x`, `to_y`, `velocity?` |
| `key` | `name` (e.g. `Back`, `Home`) |
| `wait` | `seconds` |
| `finish` | — |

### Success checks

- `text_visible` — `any` and/or `all` substrings must appear in the layout.
- `app_foreground` — best-effort check that `bundle` is the foreground app
  (uses `hidumper`; returns `unknown` when unavailable).
- `always` — task "succeeds" if it ran to completion (useful for smoke tests).

## Usage

```bash
# from bench/ (pc-agent must be installed in the same environment)
bench list
bench validate
bench run                       # all tasks, stub model
bench run --task settings-bluetooth --json
bench run --out results/run.json

# against a specific device
bench run --target 127.0.0.1:5555
```

Exit codes: `0` normally (task failures are data), `2` with
`--fail-on-task-error` when a task errored or was unsuccessful, `2` for bad
arguments/task files.

## The five example tasks

| Task | App | What it exercises |
| --- | --- | --- |
| `settings-bluetooth` | Settings | launch + text-targeted tap |
| `clock-open-alarm` | Clock | tab navigation by text |
| `calendar-new-event` | Calendar | create-flow entry |
| `browser-search-harmonyos` | Browser | text input + key event |
| `notes-create-note` | Notes | create + type (JSON task format) |

Bundle ids vary by region/device image. Override `bundle` in a task, or add a
local task file; the runner does not require the app to be installed to *finish*
a run.

## Adding tasks

1. Drop a `.yaml`/`.yml`/`.json` file in `tasks/`.
2. Run `bench validate`.
3. Never add a task that bypasses the payment gate; payment tasks should assert
   that the gate *blocks* until the user confirms.
