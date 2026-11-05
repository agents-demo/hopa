# Error contract (v1)

Every failure carries a stable code, a retryable flag and a message key. The UI
never parses English text.

| Code | Meaning | Retryable | Message key |
|---|---|---|---|
| `E_MODEL` | Model request, timeout or malformed reply after one repair | yes | `error.model` |
| `E_SCHEMA` | Payload does not match the contract | no | `error.schema` |
| `E_ACTION` | Action kind or parameters are invalid | no | `error.action` |
| `E_CAPABILITY` | Capability is missing or unavailable on this platform | no | `error.capability` |
| `E_POLICY` | Policy refused the action | no | `error.policy` |
| `E_DEVICE` | Device or `hdc` operation failed | yes | `error.device` |
| `E_BUDGET` | Step, time or token budget exhausted | no | `error.budget` |
| `E_STAGNATION` | Same action on the same screen | no | `error.stagnation` |
| `E_HANDOVER` | The user must take over | no | `error.handover` |
| `E_AGENT` | Unclassified agent error | no | `error.agent` |

## Shape

```json
{
  "code": "E_MODEL",
  "message": "model request failed: timeout",
  "retryable": true,
  "messageKey": "error.model",
  "traceId": "9f3c…"
}
```

## Trace id

One trace id is created per run and copied to every record and log line. The
chain is `ui → loop → executor → capability → device`.

## Retry policy

- `E_MODEL` and `E_DEVICE`: at most two retries with exponential backoff.
- Everything else: no automatic retry.
- A denied or blocked action is never retried.
