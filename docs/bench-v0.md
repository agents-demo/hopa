# HOPA-Bench v0

The first benchmark slice: twenty task definitions, four success predicates and a stable
failure taxonomy. It validates the task format and the runner. **No device run
has been recorded yet**; the numbers below are from the local test harness.

## Task format

A task is YAML or JSON:

```yaml
schema_version: 1
id: settings-bluetooth
goal: "Open Settings and reach the Bluetooth screen"
app: Settings
bundle: com.huawei.hmos.settings
success:
  type: text_visible
  any: ["Bluetooth", "Bluetooth settings"]
steps:
  - action: launch
  - action: wait
    seconds: 2
  - action: tap_text
    text: Bluetooth
max_steps: 10
```

## Predicates

| `success.type` | Meaning | Required |
|---|---|---|
| `text_visible` | Any/all terms are visible | `any` or `all` |
| `node_exists` | A node with the id or text exists | `id`, `any` or `all` |
| `app_foreground` | The bundle is the foreground app | `bundle` (or task bundle) |
| `screen_hash` | The visible-text hash matches | `hash` |
| `always` | Unconditional (used to test the runner) | — |

`screen_hash` is `sha256` of the visible text joined by newlines. It is stable
across refs and timestamps, so it is safe for fixtures.

## Failure taxonomy

| Value | Meaning |
|---|---|
| `target_not_found` | A tap target was not in the tree |
| `unsupported_action` | The task used an action the runner does not know |
| `schema` | A step had bad parameters |
| `device` | `hdc` / layout / screenshot failure |
| `predicate_not_met` | Actions ran but the success check failed |
| `exception` | Unclassified crash |
| `step_failed` | A step failed without a more specific class |

Every `TaskResult` carries `success`, `failure`, `steps`, `latency_ms` per step,
`tokens`, `error` and `duration_s`.

## Current tasks

The directory now holds **20 task definitions**:

1. `settings-bluetooth` — reach Bluetooth
2. `clock-open-alarm` — open the Alarm tab
3. `calendar-new-event` — create an event
4. `browser-search-harmonyos` — search in the browser
5. `notes-create-note` — create a note
6. `clock-alarm-tab`
7. `clock-create-alarm-0730`
8. `calendar-event-tomorrow`
9. `notes-search`
10. `contacts-find`
11. `browser-first-result`
12. `browser-read-price`
13. `browser-fill-form-no-submit`
14. `messages-draft-no-send`
15. `messages-attach-file`
16. `music-play-pause`
17. `music-search`
18. `files-locate`
19. `settings-wifi-toggle`
20. `settings-brightness`

Only the first five were exercised on a device. The rest are defined but their
bundles and selectors must be confirmed on a real HarmonyOS build.

All twenty validate:

```bash
python -m hopa_bench validate --tasks bench/tasks
# ok ... 20 task(s) valid
```

## Local results

| Check | Result |
|---|---|
| Task files valid | 20/20 |
| Runner unit tests | pass |
| Predicate tests | pass |
| Device run | not run |
| Real-model run | not run |

## How to run

```bash
# with a connected emulator or phone
bench run --tasks bench/tasks --json --out .hopa/bench-v0.json
```

With no device, only `list`, `validate` and the unit tests are meaningful.

## What v0 does not prove

- It does not prove that a real model can complete the tasks.
- It does not prove that the 20 tasks are stable across runs on a device.
- It does not include safety tasks; those need an approval predicate.

The next slice is [Bench v1](../docs/rebuild-plan.md#77-bench-v1-20-tasks).
