# Observation contract (v1)

An **observation** is the only picture of the screen the model sees. It is
redacted, hashable and scoped to one moment.

- Schema: [`contracts/schemas/observation.schema.json`](../../../contracts/schemas/observation.schema.json)
- Producer: `hopa-baseline observe` on the PC evaluation rig; the ArkTS a11y capability on
  device.
- Consumer: the loop, the approval policy, the run record.

## Lifecycle

```
uitest dumpLayout ──► parse_layout ──► redact ──► assign refs
      ──► flatten text ──► truncate ──► hash ──► Observation(v1)
```

An observation is immutable once built. A new dump always produces a new
observation, a new ref namespace and a new hash.

## Fields

| Field | Type | Meaning |
|---|---|---|
| `schemaVersion` | `"1"` | Contract major version. |
| `id` | string | `obs_<epoch_ms>`. Not unique across devices. |
| `timestamp` | integer | Epoch milliseconds when the dump was taken. |
| `displayId` | integer | Display that produced the tree. |
| `windowId` | string | Active window, or `"active"` when unknown. |
| `rotation` | 0/90/180/270 | Screen rotation. |
| `density` | number | Device density. `1.0` when unknown. |
| `screenSize` | `{width,height}` | Physical pixels. |
| `focus` | ref | Focused node, or `""`. |
| `text` | string | Flattened, redacted visible text. |
| `tree` | node | Synthetic root; real nodes start at `e1`. |
| `screenshotRef` | string | Local path or URI, or `""`. |
| `app` | string | Bundle or app label, or `""`. |
| `hash` | `sha256:…` | Content hash. |
| `truncated` | boolean | The tree was capped. |

A node has `ref`, `type`, `text`, `description`, `id`, `bounds`, `clickable`,
`enabled`, `checked`, `scrollable`, `visible`, `focused`, `children`.

## Ref rules

- Refs are assigned in **pre-order**: a parent always has a lower number than
  its children.
- The synthetic root has `ref: ""`. Real nodes are `e1`, `e2`, …
- Assignment is deterministic: the same tree produces the same refs.
- **Refs expire on the next observation.** A ref from step N is stale at step
  N+1. The executor refuses a stale ref; it never guesses a coordinate.
- Records store the observation hash. A ref inside a record is audit metadata
  and is never reused as a live target.

## Redaction

Before the text leaves the process, the rig removes:

- email addresses;
- phone numbers;
- card-like digit runs (13–19 digits, spaces or dashes allowed);
- values after `password`, `passcode`, `pin`, `密码`, `口令`;
- 4–8 digit codes on a line that mentions OTP, code, verification, 验证码,
  校验码 or 动态码.

A false positive costs context; a false negative leaks a secret. The rule is
deliberately conservative.

## Hashing

`hash = sha256(canonical_json({displayId, windowId, rotation, width, height,
focus, text, tree}))` with sorted keys and no whitespace. The screenshot is
**not** part of the hash.

Machine-readable values and a cross-client vector:

- [`contracts/observation/limits.v1.json`](../../../contracts/observation/limits.v1.json)
- [`contracts/fixtures/observation-hash.json`](../../../contracts/fixtures/observation-hash.json)
- `tools/checks/check-observation-hash.py` recomputes it in CI.

## Truncation

The tree is capped at 400 nodes. The focus path is always kept even when it
falls outside the first 400. `truncated: true` tells the model that content is
missing. Text is capped at 6,000 characters.

## Coordinates

`uitest` bounds are physical pixels `[x1, y1, x2, y2]`. The center is
`((x1+x2)/2, (y1+y2)/2)` rounded down. `density` and `rotation` are carried so
a future renderer can convert them; the current evaluation rig does not scale.

## Compatibility

- Additive fields only within major version `1`.
- A consumer that does not know a field must ignore it.
- Removing or renaming a field requires version `2` and a golden-file update.

## Verification

- `services/evals/baseline/tests/test_observation.py`
- `services/evals/baseline/tests/test_schemas.py`
- `hopa-baseline observe --json`
