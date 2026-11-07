# HOPA-Bench v0

The first benchmark slice: twenty task definitions, four success predicates and a stable
failure taxonomy. It validates the task format and the runner. A device run is
recorded at the end of this file.

## Task format

A task is YAML or JSON:

```yaml
schema_version: 1
id: settings-wlan
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
| `always` | Unconditional (used to test the runner) | â€” |

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

1. `settings-wlan` â€” reach Bluetooth
2. `clock-open-alarm` â€” open the Alarm tab
3. `calendar-new-event` â€” create an event
4. `browser-search-harmonyos` â€” search in the browser
5. `notes-create-note` â€” create a note
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

A failed step can never count as a pass: if any scripted step fails, the task is
failed even when the success text happened to be on screen before the step ran.
That rule is enforced in `Runner.run_task` and covered by
`bench/tests/test_runner.py::test_failed_step_cannot_pass_on_visible_text`.

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

## Device baseline — 2026-11-06

Device: **Pura 90 emulator**, HarmonyOS 6.1.1(24), 1320×2856, API 24.

```bash
bench run --tasks bench/tasks \
  --task settings-wlan --task clock-open-alarm --task calendar-new-event \
  --task browser-search-harmonyos --task notes-create-note \
  --target 127.0.0.1:5555 --timeout 180 \
  --json --out .hopa/bench-device-final2.json
bench report --input .hopa/bench-device-final2.json
```

| Task | Result | Reason |
|---|---|---|
| `settings-wlan` | **PASS** | reached WLAN |
| `calendar-new-event` | **PASS** | opened the new-event sheet (6 s cold start) |
| `browser-search-harmonyos` | **PASS** | typed and submitted the query (10 s cold start) |
| `settings-wifi-toggle` | **PASS** | reached the WLAN screen |
| `settings-brightness` | **PASS** | opened Display & brightness |
| `contacts-find` | FAIL | the Phone/Contacts app has no search target until a tab switch that `uitest` does not expose |
| `files-locate` | FAIL | Files shows only an unlabeled `top_search`; typing does not reach it |
| `clock-open-alarm` | FAIL | Clock is not installed on this image |
| `notes-create-note` | FAIL | Notes is not installed on this image |

Totals on the seven tasks that were actually run: **5/7 (71%)**.
On the original five v0 tasks: **3/5 (60%)**.

The emulator has **no Bluetooth** and no Clock/Notes apps, so the Settings task
uses WLAN and the two missing-app tasks cannot pass on this image. The app is
force-stopped before every task so a previous screen cannot fake a pass.

### Corrections found by the device run

- `com.huawei.hmos.contacts` does not exist; the Phone/Contacts app is
  `com.ohos.contacts`.
- `com.huawei.hmos.gallery` does not exist; Gallery is `com.huawei.hmos.photos`.
- AppGallery is `com.huawei.hmsapp.appgallery`.
- Calendar and Browser need 6-10 s cold starts before their controls appear.
- `settings-wifi-toggle` said "toggle off and on" but only opened the screen; the
  goal and steps now say what the task actually does.

The emulator also froze once (`SceneBoard` panic); after the restart the same
tasks ran. See `docs/history/emulator-crash-2026-11-06.md`.

## What v0 does not prove

- It does not prove that a real model can complete the tasks.
- It does not prove that the 20 tasks are stable across runs on a device.
- It does not include safety tasks; those need an approval predicate.

The next slice is [Bench v1](../plan/README.md#77-bench-v1-20-tasks).
