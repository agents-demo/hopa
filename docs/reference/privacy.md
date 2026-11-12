# Privacy

HOPA reads the screen to act on it. That is sensitive by default.

## Data inventory

| Data | Where | Why | Default retention |
|---|---|---|---|
| Screen text | In memory, then the model request | Decide the next action | Not stored |
| Node tree | In memory | Refs and clicks | Not stored |
| Screenshots | Local, opt-in | Debug and OCR fallback | Off by default |
| Run records | `.hopa/runs.jsonl` | Audit and replay | 30 days |
| Learned notes | Knowledge store | Reuse a known path | Until deleted |
| Model prompts | Provider | Produce a decision | Provider policy |
| API key | Env / HUKS | Authenticate | Until rotated |
| Diagnostics | Local bundle, opt-in | Support | 7 days |

## Consent

- The first run explains what is read and when.
- Screen capture is a separate consent.
- A model call is a network action; the user can run offline with the stub.
- Consent can be withdrawn; the next action stops.

## Redaction

Before text leaves the process, HOPA removes emails, phone numbers, card-like
numbers, passwords and OTPs. The rules are conservative; false positives are
preferred over leaks.

## Export and delete

- Records are plain JSONL and can be copied.
- `hopa-baseline records --path … --json` exports them.
- Delete the file and the screenshots directory to remove local history.
- In-app export/delete is not built yet.

## Encryption

- The PC store is plain JSONL. Use full-disk encryption.
- On-device encryption at rest is not implemented yet; this is a known gap.
- The API key must be stored in HUKS on device.

## No training

HOPA does not send user data for model training. The model provider's terms and
data-retention policy must be reviewed before a public release.

## Sub-processors

| Processor | Data | Notes |
|---|---|---|
| Model provider | Prompts and screen text | Chosen by the deployment; see ADR-0006 |
| App store / crash reporting | Crash metadata | Opt-in; not enabled by default |

## Children

HOPA is not directed at children. A minor-protection policy is required before
a public release.

## Status

- Data inventory: done.
- Redaction: implemented and tested.
- Retention: default documented, not enforced in code yet.
- DPIA: draft outline only.
- Privacy policy: not published.
