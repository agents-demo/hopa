# Backend deploy: Render, Frankfurt

`render.yaml` at the repository root declares two web services and one database:

| Resource | Name | Runtime | Region | Plan |
|---|---|---|---|---|
| Gateway | `hopa-backend` | Docker | `frankfurt` | `free` for v0 |
| Database | `hopa-backend-db` | Postgres 16 | `frankfurt` | `free` |
| Relay (existing) | `hopa-relay` | Python | `singapore` | `free` |

The Blueprint is the deploy. There is no deploy workflow and no `flyctl`: a push
to the connected branch rebuilds the image and Render rolls it out.

## Secrets (dashboard only, never the repository)

| Key | What it is |
|---|---|
| `HOPA_BOOTSTRAP_TOKEN` | Operator token for `POST /v1/pair/sessions`; 32+ random bytes |
| `HOPA_FCM_PROJECT` | Firebase project id |
| `HOPA_FCM_CREDENTIALS` | The service-account JSON, one line |

`DATABASE_URL` comes from the Blueprint (`fromDatabase`), so it is never copied by
hand.

## First deploy

1. In Render, create a Blueprint from the repository and accept `render.yaml`.
2. Fill the three secrets above in the dashboard.
3. Let the service build. Migrations run on boot: `Main` calls Flyway **before**
   the listener opens, so a failed migration fails the health check instead of
   serving half a schema.
4. Open `https://hopa-backend.onrender.com/v1/health` and expect
   `{"ok":true,"version":"0.1.0","db":"ok"}`.

## Verify the deploy role

RLS is `FORCE`d, but a superuser would still bypass it. Run this once against the
deployed database (Render dashboard psql):

```sql
select rolsuper from pg_roles where rolname = current_user;
```

It must return `false`. If it returns `true`, the Render user owns the cluster and
the tenant policies are not protecting anything; create a non-superuser role
before the beta.

## Free tier

A free web service sleeps after roughly 15 minutes without traffic, dropping every
WebSocket. The gateway's 25 s heartbeat keeps it awake while a device is connected,
but the exit run must warm it first:

```powershell
curl https://hopa-backend.onrender.com/v1/health
```

The free Postgres instance is also time-limited. Move both to paid plans before
beta; the evidence file records this as a release gate.

## Smoke the image locally

```powershell
docker build -f services/backend/Dockerfile -t hopa-backend .
docker run -d --rm -p 18083:8080 -e PORT=8080 hopa-backend
curl http://127.0.0.1:18083/v1/health
docker stop (docker ps -q --filter ancestor=hopa-backend)
```

Without `DATABASE_URL` the service boots with `"db":"unconfigured"`; that is the
expected smoke result.

## Exit run (20 round-trips)

After warming the service and pairing two devices:

```powershell
apps\android\gradlew.bat -p services/backend exitRun --args="--url wss://hopa-backend.onrender.com/v1/gateway --token-a <a> --token-b <b> --rounds 20"
```

Each line prints the trace id. Paste the twenty ids into
`docs/project/evidence/B1-gateway.md`.

## Rollback

Render keeps the previous deploy: use **Rollback** on the service. Migrations are
forward-only and v0 only adds tables, so the previous image still runs against the
new schema. The relay is untouched by a backend rollback.
