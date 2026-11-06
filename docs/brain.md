# HOPA brain service (v1)

The JVM reference brain. It is the first Phase 2 slice: routing and a decision
endpoint, not the full Mika port.

- JDK 17, Kotlin 2.1.0, Gson 2.11.0
- Binds to `127.0.0.1` only
- No outbound network calls
- No Android imports

## Run

```bash
./scripts/brain.sh          # or .\scripts\brain.ps1
java -cp "brain/build/brain.jar;.tools/gson-2.11.0.jar" hopa.brain.ServerKt 8731
```

Linux/macOS classpath separator is `:`; Windows uses `;`.

## Endpoints

### `GET /health`

```json
{ "status": "ok" }
```

### `GET /version`

```json
{ "version": "0.1.0", "contract": "1" }
```

### `POST /decide`

Request:

```json
{
  "goal": "打开设置",
  "settings": {
    "installed": [
      { "bundle": "com.huawei.hmos.settings", "label": "Settings" }
    ]
  },
  "sessionId": "s1"
}
```

Response (a `schemaVersion: 1` decision):

```json
{
  "action": {
    "schemaVersion": "1",
    "kind": "ui.launch",
    "app": "com.huawei.hmos.settings",
    "timeoutMs": 10000
  },
  "say": "Opening Settings.",
  "done": false,
  "needUser": false,
  "sessionId": "s1",
  "version": "0.1.0"
}
```

- Ambiguous match → `needUser: true` with `options`.
- Unknown task → `needUser: true` with a short menu.
- Payment word → `needUser: true`, never an action.
- `X-Trace-Id` is echoed in the stderr log line.

### `GET /session/{id}`

Returns the decisions recorded for that session, in order.

### `GET /knowledge?q=...`

Returns the loaded HarmonyOS knowledge entries, optionally filtered by the same
lexical matcher used by `/decide`.

```json
{ "entries": [ { "name": "settings", "display": "Settings", "bundle": "com.huawei.hmos.settings" } ] }
```

## Tests

`scripts/brain.sh` runs:

- `RouterTest` — 17 routing assertions
- `ServerTest` — 20 HTTP assertions
- `KnowledgeLoaderTest` — 14 format assertions
- `PromptBookTest` — 16 prompt/intent assertions
- `SkillLoaderTest` — 11 skill assertions

`scripts/brain-contract.py` starts the server, calls `/decide`, and validates the
reply against `schemas/decision.schema.json`.

## Not in this slice

- model calls
- the Mika 23-app and 18-site corpus
- skills and the guide catalog
- ArkTS parity
