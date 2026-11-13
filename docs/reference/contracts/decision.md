# Decision contract (v1)

A **decision** is what the model returns for one step: either one action, or a
statement that it is done, or a question for the user. It is not the loop and not
the record; the loop validates it, the gate classifies it, the executor runs it.

- Schema: [`contracts/schemas/decision.schema.json`](../../../contracts/schemas/decision.schema.json)
- Action schema: [`action.schema.json`](action.md)

## Shape

| Field | Type | Meaning |
|---|---|---|
| `action` | action or `null` | the next step; `null` when the model only speaks or asks |
| `say` | string | user-facing text for this step; may be empty when an action speaks for itself |
| `done` | boolean | true ends the turn; no action may run after it |
| `needUser` | boolean | the turn pauses for an answer; requires `options` |
| `options` | string[] | the choices shown with a question; required when `needUser` is true |
| `sessionId` | string | optional echo of the session the model was given |
| `version` | string | optional contract version |

Exactly one of these is the step: `action` present, or `done`, or `needUser`.
`additionalProperties` is false: an unknown field is a contract violation, not a
hint.

## Invariants

1. **One action per decision.** A batch of actions is a client convenience; the
   contract stays one step at a time.
2. **`done` wins.** If `done` is true and an action is present, the action is not
   executed and the decision is rejected as malformed.
3. **`needUser` implies `options`.** A question without choices cannot be shown
   honestly.
4. **Payment is never the model's call.** The model does not classify risk. The
   gate classifies the action and the observation (`read`, `sensitive`,
   `payment`); a model that claims `isPayment:false` changes nothing.
5. **Fail closed.** Unknown action kinds, missing fields, or extra fields reject
   the step; the loop reports a schema error and does not execute.

## Why this is shared

Every client has its own loop (ADR-0016) and every model provider returns its own
JSON. The decision schema is the one shape all three loops accept, so the
conformance fixtures and the evaluation suite can feed the same cases to all of
them.
