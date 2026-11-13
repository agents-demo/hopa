# A3 - policy, executor and the record chain

Date: 2026-11-13. Covers the three ticked items only.

## Commands

```
cd apps/android
.\gradlew.bat :core:test  -> 16 tests, 0 failures
```

- `ApprovalPolicyTest` — 6 cases: payment kind, tap on a payment screen, read on
  a payment screen, sensitive/unknown, trusted app, amount and merchant parsing.
- `RunChainTest` — seals and verifies a chain; a tampered record fails.
- `ConformanceTest` — the six fixtures, by name, drive the parser, classifier and
  policy and assert `classification`, `needsApproval` and `executed`.

## Code checked

- `ApprovalPolicy` reads the generated `ApprovalPolicyData` for trusted-app
  kinds, checks payments before the autonomous flag (so autonomous never
  bypasses a payment) and fails closed for unknown kinds.
- `ActionExecutor` runs classify → approval → capability → verify (hash change or
  returned text) → record; denials and unsupported kinds still append a record
  with `executed = false` and an error code.

## Not done in A3

- Room keeps every record; there is no last-100 cap and no `beginTurn`.
- The approval sheet shows the badge, amount, merchant and consequence, but has
  no highlight crop, no payment checkbox and no remember-app-for-messages.
- The 17 policy cases and the executor cases (denied, unsupported, approved
  payment, screen-diff verify) are not a test suite yet.
- No fake-capability runner: the fixtures stop at classification/policy, they do
  not execute per classification.
