# Week 1 · 15–19 Nov 2026: protocol v0, gateway, pairing, trace ids, wake-up

Status: **planned.** Written 2026-11-15. Parent: [`weekly-plan.md`](weekly-plan.md),
tracked in [#32](https://github.com/agents-demo/hopa/issues/32).

The week builds the first real backend slice and freezes the protocol that weeks
2–8 build on. Nothing here decides a step, executes a device command or stores a
conversation: it authenticates devices, routes task messages inside a household,
wakes a sleeping phone and records where every message went.

## 1. Goal

A paired Android phone and a paired PC can, through the deployed EU gateway,
send each other a signed-in task message, have it deduplicated, traced end to end
and delivered after a wake-up — with every table keyed by `household_id` and
`member_id` from the first migration.

Exit check: **20 of 20 scripted round-trips**, one real FCM wake, and the
1,000-attempt isolation suite green in CI (§8).

## 2. Non-goals

- No accounts, sign-in, invites or roles — pairing creates a household of one
  with the device owner as member (week 2 signs into that row).
- No conversation sync, no attachments, no `file.send` (weeks 2, 3, 6).
- No approval routing (week 5).
- No end-to-end payload encryption. TLS is enforced in transit and the key model
  is **decided** on Thu 19 Nov; wrapping lands in week 2. The payload column is
  `bytea` so ciphertext needs no migration.
- No `hdc`, `adb`, UI Automation or screen content: the gateway carries task
  messages, never device commands.
- No compatibility with `services/relay`: it keeps running unchanged for shipped
  clients until the Android and Windows builds move to the gateway.

## 3. Decisions taken

| Decision | Value | Why |
|---|---|---|
| Language and runtime | Kotlin 2.0.21, JDK 21 runtime, JVM toolchain 17 for libraries | One language with the clients; `packages/core` and `packages/data` are already pure JVM |
| HTTP and WebSocket | Ktor 3 + Netty, kotlinx.serialization | One server for `/v1` and `/v1/gateway`; no `hopa_wire` WS workaround (that exists only because Render ran `pip --no-deps`) |
| Build | `services/backend` has its own `settings.gradle.kts` including `:core` and `:data` | Precedent: `apps/windows/sidecar`; keeps `packages/` single-copy (ADR-0018) |
| Persistence | PostgreSQL 16 + Flyway; HikariCP; plain SQL over JDBC (no ORM) | Row-level security needs explicit statements; the schema is small |
| Queue | Postgres rows, not Redis | A task is durable state, and the RFC gives it a state machine |
| Tenancy | `household_id` + `member_id` on every tenant table, RLS enforced | RFC review point 1; cheaper now than a migration later |
| Tokens | Opaque, SHA-256 at rest: access 15 min, refresh 30 days rotating | Revocation in week 2 needs an instant cut-off, not a JWT expiry |
| Trace ids | W3C `traceparent`, server assigns at ingress if absent | Fits the console's "task trace by trace id" and the existing `traceId` in `errors.md` |
| Wake-up | FCM HTTP v1, data-only, `priority: high`, 5-min TTL, no payload contents | The phone must wake without the server reading the message |
| Hosting | Render (Frankfurt) + Render Postgres 16 (Frankfurt), one Docker web service | Already the repo's host for `hopa-relay`; EU data residency, WebSocket support, Blueprint deploy, managed backups |
| Deploy tier | Render free web service for v0; move to `starter` before beta | No cost during the build. A free service sleeps after ~15 min idle and drops every socket, so the exit run warms it first and the upgrade is a release gate |

## 4. Protocol v0

Frozen Monday 16:00. It is the artifact weeks 2–8 extend; after the freeze, a
change needs a version bump and a fixture, not a conversation.

### 4.1 Transport

- REST over HTTPS under `/v1` for pairing, tokens, health and trace lookup.
- One WebSocket per device at `wss://<host>/v1/gateway`, authenticated with
  `Authorization: Bearer <access token>` (never a query parameter, which reaches
  logs and proxies).
- JSON text frames, UTF-8, 64 KiB cap, no compression in v0.
- Heartbeat: server `ping` every 25 s, client `pong`, dead after 90 s.
- Unknown major version → close with `E_VERSION`, never best-effort parsing.

### 4.2 Envelope

```json
{
  "v": 1,
  "id": "018f3a5e-6b1c-7c3a-9d2e-4f5a6b7c8d9e",
  "type": "task.create",
  "trace": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "ts": 1763212800123,
  "from": "dev_01H...",
  "to": "dev_01H...",
  "task": "tsk_01H...",
  "body": {}
}
```

| Field | Set by | Rule |
|---|---|---|
| `v` | sender | major version; `1` only in v0 |
| `id` | sender | UUID; the idempotency key, unique per household for 24 h |
| `type` | sender | one of §4.3; unknown type → `E_UNSUPPORTED` |
| `trace` | sender, or server | valid `traceparent`; the server replaces an invalid one and echoes the assigned value |
| `ts` | sender | sender clock, ms; ordering is server-assigned, not trusted |
| `from` | server | device id from the access token; a client value is ignored |
| `to` | sender | target device id; must share the household |
| `task` | server | assigned on the first `task.create` and copied on every later message |
| `body` | sender | type-specific, `bytea`-safe ciphertext from week 2 onward |

`household_id` is **never** on the wire: the server derives it from the token, so
a client cannot ask for another household's data even by accident.

### 4.3 Message types

| Type | Direction | Meaning |
|---|---|---|
| `device.hello` | device → server | `{platform, name, appVersion, capabilities, pushToken}`; starts presence |
| `device.hello.ack` | server → device | `{session, serverTime, heartbeatSec, queued, peers}` — `peers` is the roster, so a join is announced once and a replay cannot double it |
| `presence` | server → peers | `{device, online, peers}` inside one household |
| `task.create` | device → device | the request; server assigns `task`, replies `ack` to the sender |
| `task.ack` | server and device | accepted by the server; then delivered to the target |
| `task.progress` | target → sender | `{step, note}` — no screen content |
| `task.result` | target → sender | terminal success, `{summary, artifacts}` |
| `task.error` | target → sender | `{code, message, retryable}`, codes from `docs/reference/contracts/errors.md` |
| `task.cancel` | sender → target | best-effort; target answers `task.error` with `E_REFUSED` if already done |
| `error` | server → device | `E_AUTH`, `E_TENANT`, `E_VERSION`, `E_RATE`, `E_QUEUE`, `E_SCHEMA` |
| `ping` / `pong` | both | application-level liveness alongside WS ping |

`task.needs_approval` is accepted as an approval-only task: the actor sends it
with `{goal, approval}`, the approver answers with `task.result` carrying
`{approval:{allow}}`, and the server stores `needs_approval` as a task state.
Role routing and signed household decisions remain week-5 work.

### 4.4 Invariants

1. **Idempotent.** `(household_id, id)` is unique; a replay returns the stored
   response and does not re-route. A reconnect may resend freely.
2. **Ordered per task in storage.** The server appends `seq` to `task_events` for
   every event on a task. The wire does not carry `seq` in v0, so a receiver
   orders by arrival; gap detection and replay-on-gap travel with the sync work.
   A test proves that concurrent events on one task still get distinct numbers.
3. **Tenant-first.** `to` is resolved to a household before any row is written;
   a mismatch is refused with `E_TENANT` and logged as a security event.
4. **Durable.** A task survives both sockets; offline targets get `queued` and
   delivery on `device.hello`, with `deadlineAt` from the body (default 10 min).
5. **Content-blind.** The server never renders `body`, never logs it, and never
   puts it in a push payload.

### 4.5 Artifacts to freeze

- `spec/openapi/backend.v1.yaml`: `/v1/health`, `/v1/version`,
  `/v1/pair/sessions`, `/v1/pair/claim`, `/v1/token/refresh`,
  `/v1/traces/{traceId}`.
- `spec/schemas/gateway.v1.schema.json`: envelope + `oneOf` body per type.
- `spec/fixtures/gateway-v0.json`: 14 vectors — happy path each direction,
  duplicate id, unknown version, unknown type, cross-household `to`, offline
  target, expired deadline, oversized frame, bad token, revoked token, cancel
  after result, missing trace, invalid trace, `needs_approval` acceptance.
- `docs/reference/protocols.md`: a row for the gateway; `spec/openapi/README.md`
  gains `backend.v1.yaml`.

## 5. Shape

```
Android ──wss──┐                    ┌── Postgres (Render, Frankfurt)
               ├── Ktor gateway ────┤     households, members, devices,
Windows ───────┘        │            │     pairing_sessions, refresh_tokens,
                        │            │     tasks, task_events, idempotency_keys,
                        ├── FCM v1   │     trace_spans
                        └── Render (Frankfurt), one container, /v1/health checks
```

```
services/backend/
├─ settings.gradle.kts        includes :core and :data
├─ build.gradle.kts           Ktor, Hikari, Flyway, serialization
├─ src/main/kotlin/com/hopa/backend/
│  ├─ Main.kt                 config from env, Ktor module wiring
│  ├─ http/                   /v1 routes, auth filter, error mapping
│  ├─ gateway/                WS sessions, presence, routing, heartbeat
│  ├─ protocol/               envelope codec + validators (shared with tests)
│  ├─ pairing/                sessions, claim, token issue and rotation
│  ├─ push/                   FCM HTTP v1, rate caps
│  ├─ store/                  JDBC repositories, RLS transaction helper
│  └─ trace/                  traceparent, span recording, query
├─ src/main/resources/db/migration/V1__init.sql
├─ src/test/kotlin/...        unit, fixture, Testcontainers integration
└─ Dockerfile                 distroless JRE + jlink runtime
```

## 6. Data model v0

Every table below carries `household_id` (and `member_id` where a person owns the
row). `tasks`, `task_events`, `idempotency_keys` and `trace_spans` are the four
that grow fastest; they get a monthly partition note in the runbook, not a
partition in week 1.

| Table | Key columns | Notes |
|---|---|---|
| `households` | `id`, `name`, `created_at` | created by the first pairing |
| `members` | `id`, `household_id`, `role`, `display_name` | one `owner` per household in v0 |
| `devices` | `id`, `household_id`, `member_id`, `platform`, `name`, `public_key`, `alg`, `push_token`, `capabilities`, `last_seen_at`, `revoked_at` | key stored, not used until week 2 |
| `pairing_sessions` | `id`, `household_id`, `member_id`, `code_hash`, `expires_at`, `claimed_at` | 5-min TTL, single use |
| `refresh_tokens` | `id`, `device_id`, `household_id`, `token_hash`, `issued_at`, `expires_at`, `rotated_from`, `revoked_at` | rotation detects reuse |
| `access_tokens` | `id`, `device_id`, `household_id`, `token_hash`, `expires_at` | 15-min rows, pruned hourly |
| `tasks` | `id`, `household_id`, `member_id`, `from_device`, `to_device`, `state`, `trace_id`, `deadline_at`, `created_at`, `updated_at` | states: `queued`, `delivered`, `acked`, `progress`, `done`, `failed`, `cancelled` |
| `task_events` | `id`, `task_id`, `household_id`, `member_id`, `seq`, `kind`, `body bytea`, `at` | append-only; the replay source |
| `idempotency_keys` | `household_id`, `message_id`, `response jsonb`, `expires_at` | unique `(household_id, message_id)` |
| `trace_spans` | `household_id`, `trace_id`, `span_id`, `operation`, `started_at`, `duration_ms`, `status`, `attributes` | accept, route, wake, ack |

RLS: enabled on all ten; policy `household_id = current_setting('hopa.household_id')::uuid`.
The repository opens a transaction, `SET LOCAL hopa.household_id = ?`, and only
then queries. A test connects as the app role and proves a cross-household
`select` returns zero rows.

## 7. Work plan

| Day | Lane A (Amir) | Lane B (Batya) |
|---|---|---|
| Sun 15 | Protocol §4 written, ADR-0022, spec + schema + fixtures | Render Blueprint and Postgres 16 in Frankfurt; `V1__init.sql` first draft |
| Mon 16 | **16:00 freeze**; Ktor skeleton, `/v1/health`, envelope codec + fixture tests | Fly app, Dockerfile, CI job, migrations on deploy; RLS test harness |
| Tue 17 | Pairing endpoints, opaque tokens, refresh rotation; gateway handshake and presence | Repositories + transaction helper; trace span writer; health with DB and queue depth |
| Wed 18 | Routing, idempotency, queue and replay, cross-household refusal | FCM service account and secrets; mock-FCM test double; log pipeline and redaction check |
| Thu 19 | FCM wake path, trace query, deploy, exit run | 1,000-attempt isolation suite in CI, backup/restore note, evidence file, key-model decision |

## 8. Exit check (Thu 19 Nov)

| # | Check | Target | Where it is proven |
|---|---|---|---|
| 1 | Scripted round-trips on the deployed EU instance | 20/20 (10 each direction) | `docs/project/evidence/B1-gateway.md` with trace ids |
| 2 | Replay: the same `task.create` sent 3× | 1 task, 1 delivery | integration test name in the evidence file |
| 3 | Cross-household attempts | 1,000 refused `E_TENANT`, 0 rows written | CI job output |
| 4 | Real FCM wake on a sleeping phone | delivered, socket reconnects, task arrives | timestamps and the `trace_spans` rows |
| 5 | Route latency in-region | p95 < 150 ms (measure, record) | trace duration histogram |
| 6 | No secrets or payloads in logs | grep of a day's logs is clean | evidence file, command shown |
| 7 | Migrations | fresh database and an existing one both apply; no manual SQL | CI + deploy log |
| 8 | No client regression | HOPA-Bench still 20/20 | `docs/project/evidence/B1-gateway.md` |

Note on the weekly plan's wording ("the week plan's Thursday definition of done:
20 of 20 runs"): week 1 has no loop to run, so it is read as 20/20 **gateway**
round-trips plus the bench unchanged. The 20/20 bench gate that matters is the
week 3 demo.

## 9. Risks

| Risk | Effect | Mitigation | Owner |
|---|---|---|---|
| Contract freeze slips past Monday | The week fills with code that the fixtures then invalidate | Freeze §4 even if handlers are stubs; anything after the freeze is a version bump | A |
| FCM needs a real Google project and a service account | Wake-up blocks the exit check | Create the project Monday, keep the mock-FCM double as the CI path, test on the phone Thursday | B |
| Android in Doze drops the wake | Late tasks, a false "it works" | Data-only high priority, deadline on every task, measure wake→deliver rather than assume it | A |
| RLS bypassed by a pool connection without `SET LOCAL` | Tenant leak — the one bug that ends the beta | Every repository call goes through one transaction helper; CI runs as the app role; the 1,000-attempt suite | B |
| Opaque tokens cost a DB read per message | Latency at 5k sockets | 5-second in-process cache keyed by token hash; revoke invalidates the key | A |
| JVM footprint on a small instance | Cost, OOM at load | jlink runtime, `-XX:MaxRAMPercentage`, measure the idle RSS in the evidence file | B |
| Free web service sleeps after ~15 min idle | Sockets drop and a wake lands on a stopped process | Warm the service before the exit run; upgrade to `starter` before beta | A |
| Two engineers, one contract | Review starvation | Lane B reviews the spec change before it is frozen, lane A reviews the schema | both |

## 10. Rollback

The deploy keeps the previous image and the Fly release history; a rollback is
`fly deploy --image <previous>` with the migrations **forward-only** (v0 adds
tables, so the previous image still runs). No client depends on the gateway yet,
so an outage costs nothing in production; the relay is untouched.

## 11. Open decisions

- [x] Hosting confirmed: Render in Frankfurt with Render Postgres 16 (evidence:
      [`tasks/week1b.md`](tasks/week1b.md) task B8). The web service stays on the
      free tier for v0 and moves to `starter` before beta, because a sleeping
      service drops every socket.
- [ ] Access tokens: opaque now (chosen) or a signed JWT from day one, if the
      week 2 console needs offline verification.
- [ ] Android slice owner: QR scan, FCM token registration and the gateway client
      are Clients-team work (Michael/Chaya). Week 1 does not block on them; week
      2 does.
- [ ] Household of one: created at pairing (chosen) or at sign-in in week 2, with
      pairing anonymous until then.
- [ ] FCM project owner and where the service-account JSON lives (secret store,
      never the repository).

## 12. Checklist

Every box is a change, a test or an artifact, not a meeting.

### W1.0 Contract freeze — Monday 16:00

- [ ] `docs/design/decisions/0022-backend-kotlin-and-shape.md` written and indexed
      in `docs/design/decisions/README.md`.
- [ ] `spec/openapi/backend.v1.yaml` covers the six `/v1` paths of §4.5.
- [ ] `spec/schemas/gateway.v1.schema.json` validates the envelope and each
      body variant.
- [ ] `spec/fixtures/gateway-v0.json` holds the 14 vectors of §4.5 and a
      runner in `src/test` replays them.
- [ ] `docs/reference/protocols.md` and `spec/openapi/README.md` list the new
      artifacts.
- [ ] Freeze comment on #32 with the commit sha and the list of frozen files.

### W1.1 Service skeleton and CI

- [ ] `services/backend/settings.gradle.kts` and `build.gradle.kts` (JDK 21,
      Kotlin 2.0.21, Ktor 3, HikariCP, Flyway) include `:core` and `:data`.
- [ ] `Main.kt` starts Ktor with config from environment only; no secret defaults.
- [ ] `GET /v1/health` and `GET /v1/version` answer without a token and report DB
      state and queue depth.
- [ ] A `backend` job in `.github/workflows/ci.yml` runs `ktlintCheck`, `test` and
      a Postgres service container.
- [ ] `python tools/checks/check-tree.py` stays at zero violations.

### W1.2 Schema v0

- [ ] `V1__init.sql` creates the ten tables of §6 with `household_id` and
      `member_id` on every tenant table.
- [ ] RLS enabled with the household policy on all ten tables.
- [ ] One transaction helper sets `hopa.household_id` and every repository uses it.
- [ ] Testcontainers test applies migrations from empty, re-applies as a no-op,
      and proves a cross-household select returns zero rows.
- [ ] Deploy runs migrations before the health check passes.

### W1.3 Pairing and tokens

- [ ] `POST /v1/pair/sessions` mints a session behind a bootstrap token, returns
      the QR payload and expires in 5 minutes.
- [ ] `POST /v1/pair/claim` accepts a device public key, platform, name and push
      token, creates household, member and device rows, and returns tokens.
- [ ] `POST /v1/token/refresh` rotates the refresh token and rejects reuse.
- [ ] Tokens are stored as SHA-256 hashes; no plaintext token exists in the
      database (asserted by test).
- [ ] Tests cover double claim, expired session, wrong code and the 5/min rate
      limit returning `E_RATE`.

### W1.4 Gateway

- [ ] `WSS /v1/gateway` authenticates the bearer token on connect, answers
      `device.hello` with `hello.ack`, and enforces the 25 s heartbeat and 90 s
      timeout.
- [ ] Presence is tracked in memory and in `devices.last_seen_at`, and `presence`
      events reach only same-household peers.
- [ ] `task.create`, `task.ack`, `task.progress`, `task.result`, `task.error` and
      `task.cancel` route between two devices of one household.
- [ ] A `to` outside the household is refused with `E_TENANT` before any write and
      recorded as a security event.
- [ ] `(household_id, id)` idempotency returns the stored response for 24 hours.
- [ ] An offline target leaves the task `queued` and delivers it on the next
      `device.hello`, honouring `deadlineAt`.
- [ ] Limits are enforced and tested: 64 KiB frame, 20 messages/s per device,
      64 KiB body.

### W1.5 Wake-up

- [ ] FCM HTTP v1 client sends a data-only high-priority message with a 5-minute
      TTL and no body content.
- [ ] A wake is attempted only for an offline target, at most 6 per minute per
      device, deduplicated per task.
- [ ] `device.hello` upserts the push token; an invalid registration clears it and
      retries on the next connect.
- [ ] A mock-FCM test asserts the request body, the priority and the rate cap.
- [ ] One real phone in the background receives a wake and the task within the
      deadline.

### W1.6 Trace, deploy and evidence

- [ ] The gateway assigns or validates `traceparent` at ingress and echoes it in
      the response and every log line.
- [ ] `trace_spans` records accept, route, wake and ack, and
      `GET /v1/traces/{traceId}` returns the chain for the caller's household only.
- [ ] Logs are JSON on stdout with `trace_id`, `household_id`, `device_id` and
      `task_id`, and never a token or a body.
- [ ] A distroless image builds from the jlink runtime and boots under 512 MB.
- [ ] Render Blueprint (`render.yaml`) with a Docker web service and Postgres 16
      in Frankfurt; secrets set in the dashboard, never committed; deploy is a
      push to the connected branch.
- [ ] `docs/project/evidence/B1-gateway.md` records the exit-check table with
      commands, trace ids and timestamps.
