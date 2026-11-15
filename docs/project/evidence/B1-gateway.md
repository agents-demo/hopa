# B1 â€” week-1 gateway evidence

Date: 2026-11-15. Spec: [`../plan/backend/week1.md`](../plan/backend/week1.md)
section 8. Slice plan: [`../plan/backend/tasks/week1b.md`](../plan/backend/tasks/week1b.md).

This file records what is proven, with which command, and what still needs the
deployed instance or a phone. A box is not ticked on intention.

## Exit check

| # | Check | Target | Result | Where it is proven |
|---|---|---|---|---|
| 1 | Scripted round-trips | 20/20 | **local 20/20**; deployed run pending the account owner | `ExitRunTest > twenty round-trips over a real socket return twenty trace ids` |
| 2 | Replay: the same `task.create` 3Ã— | 1 task, 1 delivery | passed | `PgTaskRoutingTest > the same message id three times creates one row and one delivery` |
| 3 | Cross-household attempts | 1,000 refused `E_TENANT`, 0 rows | passed locally; CI sets `HOPA_ISOLATION_ATTEMPTS=1000` | `TenantIsolationTest > a thousand cross-household reads leak nothing` |
| 4 | Real FCM wake on a sleeping phone | delivered, reconnect, task arrives | **deferred: needs deploy + phone** | `WakeTest` proves the request from a fake FCM; the phone is Clients-team work |
| 5 | Route latency in-region | p95 < 150 ms | **deferred: needs deploy** | trace durations exist; no deployed histogram yet |
| 6 | No secrets or payloads in logs | a day's logs are clean | passed for the log writer | `JsonLogTest > a refusal logs identifiers but never the token or the body` |
| 7 | Migrations | fresh and existing both apply | passed | `DatabaseTest > migrations apply from empty and a second run is a no-op` |
| 8 | No client regression | HOPA-Bench 20/20 | **deferred: needs bench** | not run in this slice |

Rows 4, 5 and 8 are deliberately marked deferred. The gateway is not deployed and
the phone-side client is another team's work.

## Commands

```powershell
# Whole backend suite (Docker Desktop must be running; Testcontainers)
apps\android\gradlew.bat -p services/backend :test --rerun-tasks

# One thousand isolation attempts explicitly
$env:HOPA_ISOLATION_ATTEMPTS = "1000"
apps\android\gradlew.bat -p services/backend :test --tests "*TenantIsolationTest*"

# Contracts
py -3 tools/checks/check-gateway-fixtures.py
py -3 tools/checks/check-links.py

# Image smoke (no database: db must be "unconfigured")
docker build -f services/backend/Dockerfile -t hopa-backend .
docker run -d --rm -p 18083:8080 -e PORT=8080 hopa-backend
curl http://127.0.0.1:18083/v1/health
```

## Trace ids from the deployed exit run

Paste the twenty lines printed by `exitRun` here. Until then this section is the
honest gap:

```
pending deploy
```

## Notes

- The gateway is one Render web service in Frankfurt with Render Postgres 16 in
  the same region; `render.yaml` is the source of truth.
- The container was built and smoked locally: `hopa-backend:smoke` is 299 MB,
  `GET /v1/health` returned `{"ok":true,"version":"0.1.0","db":"unconfigured"}`
  without a database.
- The free web service sleeps when idle. Warm `/v1/health` before the exit run;
  move to `starter` before beta.
- RLS is forced on all ten tables and tested as `hopa_app`, not as a superuser.
  The deploy-role check in
  [`backend-deploy.md`](../../../services/docs/guides/backend-deploy.md) must
  return `false`.
- `queueDepth` is returned by `/v1/health` only when the request carries a valid
  token; an unauthenticated global count would need an RLS bypass.
