# Run record contract (v1)

A **run record** is one append-only, hash-chained line about one step. It is what
the run pane shows, what the evaluation scores, and what makes a claim about an
action auditable after the fact.

- Schema: [`contracts/schemas/run-record.schema.json`](../../../contracts/schemas/run-record.schema.json)
- Action schema: [`action.md`](action.md)

## Shape

| Field | Type | Meaning |
|---|---|---|
| `schemaVersion` | `"1"` | literal; a breaking change is a new schema file |
| `runId` | string | one question / one turn |
| `step` | integer | 0-based within the run |
| `timestamp` | string | ISO-8601; optional but always written by a client |
| `traceId` | string | correlates the record with logs |
| `action` | action | the step that ran (or was refused) |
| `classification` | `read` / `sensitive` / `payment` | decided by the gate, never by the model |
| `approved` | boolean or `null` | `null` when no approval was needed |
| `observationHash` | string | hash of the observation the step saw |
| `beforeHash` / `afterHash` | string | optional screen hashes around the action |
| `verified` | boolean | the post-condition check passed |
| `executed` | boolean | false for refused or unsupported actions |
| `error` | string or `null` | the error code when the step failed |
| `prevHash` | string | the previous record's `hash`, or the chain seed |
| `hash` | string | `sha256:<64 hex>` over the canonical record without `hash` |

## Invariants

1. **Append-only.** A record is never edited. A correction is a new record that
   explains itself.
2. **One chain per run.** `prevHash` links to the previous step; the first record
   links to a documented seed (currently the empty string, hashed as such).
3. **Hash covers everything else.** `hash` is computed over the record with
   `hash` removed, using canonical JSON (sorted keys, no whitespace). Any change
   to a field breaks the chain and `verify-chain` must fail.
4. **Refusals are recorded.** `executed: false`, `approved: false` and the error
   code are a record; silence is not.
5. **No secrets.** The record never carries the model key, the bridge token, or
   raw audio.

## Why this is shared

The run pane, the bench and any future backend read the same record. A client that
writes a record with a different hash rule cannot be compared with the others, and
the evaluation becomes meaningless.
