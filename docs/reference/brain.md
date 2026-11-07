# HOPA brain service (v1)

The JVM reference brain. It is the first Phase 2 slice: routing and a decision
endpoint, not the full port.

- JDK 17, Kotlin 2.1.0, Gson 2.11.0
- Binds to `127.0.0.1` only
- No outbound network calls
- No Android imports

## Run

```bash
./tools/scripts/brain.sh          # or .\tools\scripts\brain.ps1
java -cp "services/brain/build/brain.jar;.tools/gson-2.11.0.jar" hopa.brain.http.ServerKt 8731
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

The same lexical rules are ported to the shipped app in
`apps/harmony/core/src/main/ets/router/AppRouter.ets` (`AppRouterTest`). The
Kotlin service stays the reference used by the contract tests.

## PC harness integration

The harness asks the brain for the **first** action, then delegates later steps to the model:

```bash
# terminal 1: the brain
java -cp "services/brain/build/brain.jar;.tools/gson-2.11.0.jar" hopa.brain.http.ServerKt 8731

# terminal 2: the loop, with the brain in front of the model
hopa-agent run "open settings" --model openai --brain http://127.0.0.1:8731
```

Or set `HOPA_BRAIN_URL`. `BrainFirstModel` behaves as follows:

- step 0: call `/decide` with the goal and the installed bundles;
- a `ui.launch` action is executed first;
- `needUser` stops before the model and surfaces `say` + `options`;
- an app with `bundle: UNCONFIRMED` produces `needUser` ("No app bundle ... the
  web channel is next") instead of a guessed launch;
- if the brain is down, the wrapper records the error and falls back to the
  model, so a missing brain never blocks a run.

The brain is optional in the PC loop and not used by the phone app yet.

Verified against the running service on 2026-11-06:

| Goal | Result |
|---|---|
| `open settings` | `ui.launch com.huawei.hmos.settings` |
| `open calendar` | `ui.launch com.huawei.hmos.calendar` |
| `open wechat` | `needUser`: no bundle, web channel next |

## Tests

`tools/scripts/brain.sh` runs:

- `RouterTest` — 19 routing assertions
- `ServerTest` — 20 HTTP assertions
- `KnowledgeLoaderTest` — 18 format assertions
- `PromptBookTest` — 16 prompt/intent assertions
- `SkillLoaderTest` — 11 skill assertions
- `SiteLoaderTest` — 14 site assertions

`tools/scripts/brain-contract.py` starts the server, calls `/decide`, and validates the
reply against `contracts/schemas/decision.schema.json`.

## Not in this slice

- model calls
- the 23-app corpus (triaged; bundles not confirmed)
- skill execution and the guide catalog
- ArkTS parity
