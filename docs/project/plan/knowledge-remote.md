# Knowledge from the backend

Status: **implemented** (K1-K5). The app ships the same JSON bundle it can
download, keeps a downloaded copy atomically with rollback, and asks
`GET /v1/knowledge` quietly when a paired backend is configured.

## What a client does now

- The bootstrap is `knowledge.v1.json`: a generated asset in the app, a resource
  in the sidecar, nothing compiled into Kotlin. `AssetKnowledgeSource` and
  `SidecarCatalog` read it once.
- `Knowledge` (version, catalog, sites, approval, prompt rules) is passed into
  `CatalogRoutes`, `AgentLoop` and `TurnRunner`; the engine reads a value, not
  `com.hopa.knowledge` constants.
- `FileKnowledgeStore` prefers the newest valid stored bundle, falls back to the
  previous file, then to the bootstrap. Writes are temp, sync, rename; a corrupt
  or unsupported file is ignored.
- `KnowledgeUpdater` asks the backend at most once per six hours. A 304, an
  error, an unpaired phone or a refused bundle keeps the current copy silently.
- The backend serves the reviewed document with a paired token, an ETag equal to
  the bundle's digest, and 304 on `If-None-Match`.

## The document

```json
{
  "schemaVersion": 1,
  "version": "sha256:f3b76f1d3f63d446",
  "catalog": [ { "id": "...", "android": { "id": "...", "verified": true } } ],
  "sites": [ { "id": "...", "domains": ["..."] } ],
  "promptRules": [ { "id": "...", "phrases": ["..."] } ]
}
```

`tools/scripts/build-knowledge-bundle.py` writes it from
`spec/catalog/catalog.v1.json` and `spec/prompts/rules.v1.json` to
`spec/knowledge`, the backend resources, both clients and the test
resources; CI fails when any copy drifts. A Kotlin test decodes the generated
document with the app codec, so the writer and the reader cannot diverge.

## Safety floor

Approval is **not** in the bundle. A download may change which app opens; it must
not make the gate less careful. The approval table stays compiled into the app
(`ApprovalPolicyData`), so payments, delete, reset and uninstall always ask even
if a bundle is malicious.

The loader also refuses an unknown schema, a missing catalog or a document over
one megabyte, and keeps the previous version for rollback.

## Remaining

- **Done - the receipt names the bundle.** `TurnOutcome` carries the knowledge
  version this turn routed with, `MessageProof` stores it, and the expanded
  receipt shows it, so two runs can be compared honestly. The bench does not
  route through the catalog, so it has nothing to name yet.
- Deploy the backend endpoint; until then the updater gets 401/404 and keeps the
  bootstrap, which is the intended failure path.
- A signature on the bundle is optional; the loader's digest check is the seam.
- A smaller bootstrap if APK size ever matters. The catalog is ~60 KB and no
  longer duplicated as generated Kotlin.

## History

| step | what | commit |
|---|---|---|
| K1 | `Knowledge`, `KnowledgeSource`, injected into the engine | `ad2396a` |
| K2 | `KnowledgeBundle` + `KnowledgeCodec` | `392ccd5` |
| K3 | `FileKnowledgeStore` with rollback | `afbdba3` |
| K4 | `GET /v1/knowledge`, bundle writer, client, updater | `a07ef25`, `670548d` |
| K5 | bootstrap asset; no compiled catalog | this branch |

## Non-goals

- No network call blocks the first screen or a turn.
- No executable rules in a bundle; no silent removal of an approval step.
- No second knowledge format: the bootstrap, the download and the backend body
  are the same document.
