# Conformance fixtures

Every client owns its loop (ADR-0016). These cases are the behaviour all three
loops must share: the same observation and the same model reply must produce the
same decision, classification and execution.

- Data: [`conformance.json`](conformance.json)
- Checker: `tools/checks/check-conformance.py` (validates the fixtures themselves)
- Schemas: [`../schemas/`](../schemas)

## How a client runs them

For each case:

1. validate the observation against `observation.schema.json` (fixtures already
   are valid; this only proves the runner is wired);
2. parse `modelReply` as a decision; a reply that is not valid must be rejected
   with `expect.errorCode`;
3. apply the semantic rules (see below) — this is where most implementations fail;
4. classify the action from the **observation**, never from the reply;
5. decide whether approval is needed, and whether the step may execute;
6. compare with `expect`.

A runner may be a unit test, a Kotlin test, an ArkTS test or a small CLI; the file
format is the contract.

## Semantic rules the schema cannot express

| Rule | Case |
|---|---|
| `done: true` with an action is malformed | `done-with-an-action-is-rejected` |
| `needUser: true` without `options` is malformed | `a-question-needs-options` |
| a model-supplied payment flag is ignored; the screen decides | `a-model-payment-flag-changes-nothing` |
| a payment-classified action is not executed until approved | `tap-on-a-payment-screen-asks-first` |

## Adding a case

Add a case to `conformance.json`, bump nothing (the file is additive), run the
checker, then add the expectation to each client's runner in the same PR that
changes behaviour. A case that only one client can pass is a client bug or a
missing feature — record which, in the PR.
