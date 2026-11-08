# Safety model

The rules below are enforced in code, not only in prompts. The PC harness and
the ArkTS core must keep the same behaviour.

## One gate

Every action passes `DeviceExecutor` (PC) or `ActionExecutor` (device):

```
validate → classify → approve → guard → execute → observe → verify → record
```

Nothing calls a capability directly.

## Payment

- Classification comes from the **screen and the action**, never from a model
  flag. `isPayment` is dropped at parse time.
- A tap on a screen containing `pay`, `checkout`, `confirm order`, `amount`,
  `merchant`, `currency`, `支付`, `付款`, `结算` or `金额` is a payment action.
- The approval sheet carries amount, merchant and consequence.
- Approval is **never remembered**. A denied payment stops the run and is
  recorded with `approved=false`.
- Recurring-charge text (`auto-renew`, `per month`, `订阅`, `自动续费`) is
  surfaced in the approval consequence.
- Emergency numbers `110 / 112 / 119 / 120 / 122 / 999` are **blocked**, not
  approved.

## Irreversible actions

`system.sendMessage`, `system.call`, `system.delete`, `system.uninstall`,
`system.reset`, `system.share`, `system.openLink` and `sandbox.run` ask first.
The request explains what may not be undoable.

## Passwords and one-time codes

- HOPA never types into a password, passcode, OTP or CVV field. The action is
  blocked and the user takes over.
- Sensitive screens (banking, card number) are detected; unknown or unreadable
  content is handed over rather than guessed.

## URLs

`web.navigate` and `system.openLink` pass `UrlPolicy`:

- `https` only (unless the deployment explicitly allows `http`);
- no `javascript:`, `data:`, `file:`, `about:`, `blob:`;
- no `user:pass@` userinfo;
- an optional host allow-list; subdomains are allowed.

## Limits

`ActionLimiter` caps high-risk kinds per rolling hour:

| Kind | Limit |
|---|---|
| `system.sendMessage` | 20 |
| `system.call` | 10 |
| `system.share` | 20 |
| `system.delete` | 20 |
| `system.uninstall` | 5 |
| `system.reset` | 2 |
| payment kinds | 5 |

A task can also pass an explicit `allowed_kinds` allow-list; anything else is
refused before execution.

## Screenshots

- Screenshots are opt-in.
- Redaction runs before text leaves the process.
- Screenshot retention is a deployment setting; the default is to keep none
  after the run record is written.
- A screenshot is never part of the observation hash.

## Records

- Append-only JSONL.
- Each step chains to the previous hash. Editing a line is detectable with
  `hopa-agent verify-chain`.
- Denied and blocked actions are recorded too.

## Known gaps

- No ArkTS implementation of these rules yet.
- No on-device encryption at rest yet.
- No external pen-test yet.
- The approval sheet UI is not built.
