# Action contract (v1)

An **action** is one thing the agent asks the device to do. The model proposes
it; `Action.from_dict` validates it; `DeviceExecutor` is the only code that runs
it.

- Schema: [`contracts/schemas/action.schema.json`](../../contracts/schemas/action.schema.json)
- Validator: `harness/agent/src/hopa_agent/actions.py`
- Executor: `harness/agent/src/hopa_agent/executor.py`

## Kinds

| Group | Kinds | Required |
|---|---|---|
| UI | `ui.observe`, `ui.back`, `ui.home`, `ui.wait` | — |
| UI | `ui.tap`, `ui.doubleTap`, `ui.longPress` | `ref` or `x`+`y` |
| UI | `ui.type` | `text`; optional `ref` or `x`+`y` |
| UI | `ui.swipe` | `x,y,toX,toY` or `direction` |
| UI | `ui.scroll` | optional `ref`, `direction` |
| UI | `ui.launch`, `ui.stop` | `app` |
| Web | `web.navigate` | `url` |
| Web | `web.read`, `web.click`, `web.type` | kind-specific |
| System | `system.setAlarm`, `system.addEvent` | kind-specific |
| System | `system.openLink`, `system.share` | kind-specific |
| System | `system.sendMessage`, `system.call`, `system.delete` | `text` |
| System | `system.uninstall`, `system.reset` | kind-specific |
| Sandbox | `sandbox.run` | `text` (code) |
| Payment | `payment.pay`, `payment.confirm`, `payment.checkout`, `payment.enterCard`, `payment.authorize` | — |

Unknown kinds are rejected with `E_ACTION`. They are never forwarded.

## URLs and deep links

`web.navigate` and `system.openLink` pass `UrlPolicy` **before** any capability:

- `https` only (unless the deployment explicitly allows `http`);
- no `javascript:`, `data:`, `file:`, `about:` or `blob:`;
- no `user:pass@` userinfo;
- an optional host allow-list; a subdomain of an allowed host is allowed.

## `isPayment` is not a model field

The model may send `isPayment`. The parser **drops it** and records it in
`ignored_fields`. Payment is classified by `policy.py` from the action and the
screen. A model cannot clear, set or pre-approve a payment.

## Validation

- `ui.tap` and friends need a ref or a point.
- `ui.type` needs text.
- `ui.launch` needs an app. It uses the PC bridge when one is the preferred
  backend (so it also works while HOPA is in the background), otherwise the
  app's own UI context, which needs no accessibility service.
- `ui.stop` needs an app.
- `web.navigate` needs a URL.
- `system.call`, `system.sendMessage`, `system.delete` and `sandbox.run` need
  text.
- `timeoutMs` defaults to 10,000.
- A stale ref is an error, not a fallback to the last coordinate.

## Execution

```
validate → policy.decide → approval → dispatch → observe → verify → record
```

Every action returns an `Outcome` with `before`, `after`, `approved`,
`executed`, `verified`, `error` and the appended `RunRecord`.

Verification is deliberately simple in v1:

- `ui.observe` and `ui.wait` are verified when they return.
- Every other action is verified when the observation hash changes.
- A tap that leaves the screen identical is `verified: false` and stops the
  loop.

A stronger verifier (expected text or state) is Phase 1 follow-up work.

## Approval

`policy.py` returns `ALLOW`, `ASK` or `BLOCK`.

| Situation | Decision |
|---|---|
| Read-only action on a normal screen | `ALLOW` |
| Any interactive action on a payment-looking screen | `ASK`, class `payment` |
| Send, call, delete, uninstall, reset, share, open link, sandbox | `ASK`, class `sensitive` |
| Emergency number (110/112/119/120/122/999) | `BLOCK` |
| Unknown kind | rejected before policy |

No approver configured means **deny**. Payment is never remembered.

## Example

```json
{
  "schemaVersion": "1",
  "kind": "ui.tap",
  "ref": "e12",
  "timeoutMs": 10000
}
```

```json
{
  "schemaVersion": "1",
  "kind": "ui.type",
  "ref": "e8",
  "text": "Bluetooth",
  "timeoutMs": 10000
}
```
