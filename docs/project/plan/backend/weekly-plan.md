# HOPA backend: functions and weekly plan

Nov 15, 2026 · @Amir

## Summary

The backend should be HOPA's **coordination service, not its brain**: accounts and households, devices and pairing, task routing with wake-up, conversation sync, family approvals, run journals and recipe delivery. The agent loop stays in each client (ADR-0016), and the approval gate stays on the device that acts.

Today that role is split between a single-owner relay (one shared token, in-memory queue, free tier in Singapore) and the PC bridge, which keeps the only conversation store as a JSON file. Neither knows about users, households or more than one PC.

The plan below takes eight Sun–Thu weeks, 15 Nov 2026 to 7 Jan 2027. The first demo, on Thu 3 Dec, is one user with a synced Windows PC and Android phone running a simple task each way. Households and family approvals follow in weeks 4–5, and an operations console for the team grows alongside. Two engineers build it from week 1; the last section splits the work between them.

## Where it stands today

The repo has a working device plane and a public relay, but no backend: `services/backend` is a README by design (ADR-0011), and ADR-0016 moved the loop into each client. Checked against the [repo](https://github.com/agents-demo/hopa) at commit #31, 15 Nov 2026.

| Piece | What it does today | What limits it as a multi-user backend |
| --- | --- | --- |
| `services/relay` (933 lines, Python stdlib) | Phones call it; a PC dials out over WebSocket; it queues and forwards requests to that PC. `/pair`, `/refresh`, `/link/poll`, `/link/result`, `/tunnel` | One owner: tokens come from env vars (`HOPA_BRIDGE_TOKEN`, `HOPA_LINK_TOKEN`), a fixed pair code, an in-memory queue of 200, free tier in Singapore (`render.yaml`) |
| `services/bridge` (4,042 lines) | Device plane: observe, tap, type, launch over `hdc` or `adb` behind `DevicePort`; voice; the **only conversation store** (`/chats`, `/sessions`, `/images`) | The store is one JSON file on one PC: no users, no households, gone if the PC is off |
| `services/wire` | WebSocket and tunnel framing shared by bridge and relay (ADR-0010) | Framing only; no message schema or versioning for tasks |
| `contracts/openapi` | `relay.v1.yaml`, `bridge.v1.yaml` | No task protocol, accounts or sync contract yet |
| `apps/android`, `apps/windows` | Clients own the loop (ADR-0016); Windows runs the Kotlin engine in a sidecar (ADR-0021) | They expect a bridge on the LAN or the single-owner relay |

The chat store's rules are worth keeping: turns are deduplicated by id, titles are last-writer-wins, deletes are tombstones, and a `rev` counter grows on each change. The backend's sync should keep those semantics and add users, devices and encryption around them.

## Review of the week plan and the module diagram

The week plan is a sound first slice for the backend: one EU WebSocket relay with Postgres, QR pairing, FCM wake-up, trace ids, idempotent messages and a frozen task protocol. Five things are missing or will cost more later if they aren't settled now.

1. **Multi-tenancy is absent.** Week 1 pairs devices to "one account". The team map says HOPA is used by a **household** (an adult, an older parent, sometimes a child). Put `household_id` and `member_id` on every table and every routing decision in week 1. Adding them after data exists means a migration and a re-test of every route.
2. **End-to-end encryption conflicts with server-side sync.** The plan encrypts payloads so "the relay can’t read tasks or files". That is right, but then the server can store conversations only as ciphertext, and a **new device needs the household’s keys** before it can read history. Decide the key model (below) before week 4, or sync will have to be built twice.
3. **There is no conversation sync.** Today it lives in the PC bridge’s JSON file. The diagram’s Clients box shows "ask, answer" but no shared history. Once the PC is no longer the hub, the backend has to own it.
4. **The diagram has no backend box.** "Platform and services" lists four duties (pair once, encrypted link, renew access codes, message format). It also needs to own task state for **Tasks: waits, then resumes**, approval routing for **Family rules**, and the endpoints that **Recipe delivery** and the **journals** arrows use. Add those to the platform team’s list, or they fall between teams.
5. **The stack is a rewrite either way.** The plan proposes Go or Node; the repo relay is Python stdlib and single-tenant. Keep its protocol ideas (pairing rate limit, dial-out tunnel, link poll) and rewrite the server. Choose the language by who owns it for the next year, not by this week.

The plan already gets several things right: the task message set (`task.create` to `task.result`), approvals signed by the device key, a queue held until the ack, EU hosting, and a 20-run gate with trace ids. The backend plan below keeps all of these unchanged.

## What the backend must do (v1)

Eleven areas make v1, including the operations console. Each is listed with the week it lands in the plan below. The backend never decides a step and never holds the final say on a payment: it routes, stores, wakes and records. It carries task messages, never device commands: no `adb`, `hdc` or screen taps pass through it, unlike today’s relay tunnel. Each client controls apps on its own device.

| Area | Functions | Week |
| --- | --- | --- |
| Accounts and households | Sign-in (email link or passkey) with a household of one created automatically; later, invites, members and roles (owner, adult, elder, child) | 2 (one user), 4 |
| Devices and pairing | QR pairing; a device key made on pairing; device list, rename, revoke; short-lived access tokens with refresh (“renew access codes”) | 1, 2 |
| Presence and routing | WebSocket gateway; `device.hello` with capabilities (OS, apps, battery); online state; routing only between devices of the same household; rate limits | 1, 4 |
| Wake-up | FCM high-priority push to Android; a Windows tray app keeps its socket; messages queued until the ack | 1, 3 |
| Tasks | Durable state machine (`task.create` → `ack` → `progress` → `needs_approval` → `result`, plus `error` and `cancel`); retries, idempotency, deadlines, heartbeats; resume after reconnect; both directions between a user’s devices | 1 (v0), 3 |
| Conversation sync | v0: threads and turns across one user’s devices, append-only and deduplicated by id, last-writer-wins titles, tombstone deletes, a cursor per device. v1: attachments in object storage, shared household threads | 2, 6 |
| Encryption | TLS everywhere; end-to-end payloads; a household key wrapped per device; a new device admitted by an existing one | 1, 2, 6 |
| Family approvals | Send `needs_approval` to the member who must confirm; verify the signed decision; expiry; an audit trail. The device still runs its own gate | 5 |
| Journals and operations | Opt-in upload of redacted, hash-chained run records; metrics, alerts, backups; data export and account deletion for GDPR | 6, 7 |
| Recipe delivery | Signed recipe packages pinned to a target-app build; staged rollout, then rollback; devices report installed versions | 7 |
| Operations console | A web app for the team: health, connected devices, queue depth, task trace by trace id, household and device lookup, alerts, recipe rollout controls. It never shows conversation contents | 2, 3, 4, 7 |

## Architecture

&#91;embedded content: backend architecture · 3 clients, 7 services, 3 outside parts\]

Every client talks only to the gateway, which routes a message only between devices of the same household. The services behind it share one Postgres schema with `household_id` on every table, plus object storage for attachments and recipe packages.

Where today’s pieces go:

- **Relay** → the gateway. Keep its ideas: dial-out sockets, pairing rate limits, a queue until the ack. Replace its env-var tokens with per-device keys.
- **Bridge chat store and images** → conversation sync and object storage, with the same dedupe, title and tombstone rules.
- **Bridge device plane** (`hdc`, `adb`, voice) → stays a separate tool for development, evals and the verification farm. It never moves into the backend.
- **`services/wire`** → keeps framing; the task protocol v0 becomes a versioned schema in `contracts/`, next to a new `backend.v1.yaml`.

The **operations console** is a web app for the team only, behind an admin role, reading the same Postgres through the backend’s admin API. It shows health, connected devices, queue depth, a task’s path by trace id, and later alerts and recipe rollout. It never shows conversation contents, which it could not decrypt anyway.

## Future functions

These come after the beta. Each reuses the v1 tables and routes, so none of them needs a redesign if v1 keeps the household id and the task protocol versioned.

| Function | What it adds | Builds on |
| --- | --- | --- |
| Scheduled and conditional tasks | Server-side timers and triggers that wake a device (“every Friday 18:00”, “when the bill arrives”) | Tasks, wake-up |
| MCP and A2A gateway | Exposes a household’s devices as tools to outside agents (Claude, ChatGPT, Gemini) with OAuth and per-tool consent, starting with “Send to my PC” | Routing, approvals |
| A2UI relay | Approval and choice cards as A2UI surfaces, drawn on whichever device is in hand; the tap goes back to the acting device | Tasks, approvals |
| Hosted model gateway | Optional managed keys, per-household budgets and quotas, provider failover; BYOK stays the default (ADR-0016) | Accounts |
| Hosted loop | Server mode from ADR-0011: the backend runs a loop against a device farm or for thin clients | Tasks, journals |
| Caregiver view | An adult sees an elder’s or child’s tasks, approvals and alerts, by their consent | Households, approvals |
| Notification events | Turns notifications captured on a device into tasks or reminders across the household | Tasks, wake-up |
| Web client and iOS/macOS | More clients on the same protocol | Contracts |
| Billing and plans | Subscriptions per household and usage limits | Accounts |
| Organization tenants | Small offices with SSO, admin policies and audit export | Households (as a tenant type) |

## Weekly plan

Eight Sun–Thu weeks take the backend to a beta on 7 Jan 2027. The first demo, on **Thu 3 Dec**, is one user with a synced Windows PC and Android phone running a simple task in each direction. Households and family approvals follow in weeks 4–5. Each week ends with an exit check that P7’s harness runs, and a week that fails it carries the gap forward.

&#91;embedded content: backend roadmap · 8 weeks, 3 gates\]

The demo proves the single-user path. Gate 1 is the 1,000-attempt cross-household test, Gate 2 is a child’s task approved on a parent’s phone, and the beta gate is the load and security review.

| Week | Focus | Deliverables | Exit check |
| --- | --- | --- | --- |
| 1 · 15–19 Nov | Base relay (the attached plan) | Protocol v0 frozen Mon 16:00; WebSocket gateway; Postgres schema v0 with `household_id` and `member_id` on every table; QR pairing; trace ids; idempotent messages; FCM wake; deployed in the EU | The week plan’s Thursday definition of done: 20 of 20 runs |
| 2 · 22–26 Nov | One user: accounts and sync v0 | Sign-in, with a household of one created automatically; device list, revoke, token refresh; sync v0 of threads and turns across one user’s devices (cursors, tombstones, ciphertext only); console: team sign-in and a health page | A turn typed on the phone shows on the PC, and back, within 2 s (target, to measure); a revoked device is cut off within 5 s |
| 3 · 29 Nov–3 Dec | Durable tasks and the demo | Task state machine with retries, deadlines, cancel and resume; phone → PC (find a file, draft the email) and PC → phone (a system action, such as a calendar event or the share sheet); the approval card on the user’s own device; console: task trace view | **Demo Thu 3 Dec.** 20 of 20 runs in each direction; app or PC killed mid-task in 20 runs: each task resumes or ends with a named error |
| 4 · 6–10 Dec | Households | Invite and remove members; roles; routing only inside a household; console: household and device lookup | Gate 1: 1,000 cross-household attempts in CI all refused. No second real user goes on before this passes |
| 5 · 13–17 Dec | Family approvals | Approval routing by role (“a child’s purchase goes to a parent”); signed decisions verified; expiry and reminders; audit trail per task | Gate 2: a child’s task reaches the parent’s phone, is approved and completes; the audit shows every hop with its trace id |
| 6 · 20–24 Dec | Sync v1 and journals | Attachments in object storage; a new device admitted by an existing one; shared household threads; opt-in run-record upload, redacted and chain-checked | Three devices edit offline and reconnect with no lost or duplicate turn; a new device reads history only after approval |
| 7 · 27–31 Dec | Operations and recipe delivery | Metrics, alerts, nightly backups, data export and account deletion; signed recipe packages with staged rollout; console: alerts, rollout and rollback controls | Restore in under 1 hour; a deleted account leaves no row or file; a 10% rollout rolls back with versions reported within 10 minutes |
| 8 · 3–7 Jan | Hardening and beta gate | Threat-model review; load test (target to measure: 1,000 households, 5,000 sockets); service levels and runbook; staging and production split; console security review | Load test meets the agreed targets; no open high-severity finding; beta households onboarded |

Two defaults to confirm: the demo date, and what the phone does in the PC → phone task. A system action is allowed on Play; driving a phone app through accessibility is a stretch goal on a sideloaded build only. Weeks 6 and 7 fall over the holidays, so if time is short, recipe delivery moves first.

## Risks and decisions to make first

Three decisions block later weeks and should be made in week 1. The rest are risks with an owner.

- [ ] **Key model for end-to-end encryption, by Thu 19 Nov (sync v0 in week 2 needs it).** Proposal: one household content key, wrapped for each device’s public key; a new device is admitted by scanning a QR code on an existing device, which re-wraps the key. Lost all devices means lost history, unless the owner keeps a recovery code.
- [ ] **Backend language and owner, week 1.** Go or Kotlin (shared with the clients’ data types) are both reasonable; pick the one P1 and the second engineer will maintain.
- [ ] **Hosting, week 1.** An EU region with managed Postgres, Redis (or Postgres) for presence, and S3-compatible object storage. Move off the free Singapore tier before any real user data.

| Risk | Effect | Mitigation |
| --- | --- | --- |
| Android kills the socket in the background | Tasks to the phone are late or lost | FCM wake, a queue kept until the ack, and a deadline on every task |
| One household reaches another’s device or data | A privacy breach | Household id on every route and query; a cross-tenant test suite in CI from week 2 |
| Protocol changes break clients already in the field | Older apps stop working | A version field on every message; the backend accepts the current and the previous version |
| Sync conflicts on edited turns | Lost or duplicated messages | Turns are append-only; only titles and deletes change, with the rules the bridge store already uses |
| Two engineers cover backend and console | One absence stalls a lane | Each reviews the other’s pull requests, so either can cover; P7 owns the cross-tenant and soak tests |

## Who does what: two engineers

Split the work by lane, not by week: **A** owns the live path between devices (gateway, protocol, tasks, approvals, keys), and **B** owns the stored data and the console (accounts, sync, storage, operations). A is P1 from the week plan and keeps the contracts. B should be comfortable with Postgres and a web front end.

| Week | A: gateway, tasks, security | B: accounts, data, console |
| --- | --- | --- |
| 1 · 15–19 Nov | Protocol v0; WebSocket gateway; QR pairing; trace ids; FCM wake | Postgres schema v0 with household ids; EU hosting; CI deploy and migrations; logs and trace storage |
| 2 · 22–26 Nov | Device list, revoke, token refresh; key model written and agreed | Sign-in with a household of one; sync v0; console sign-in and health page |
| 3 · 29 Nov–3 Dec | Durable tasks; both task directions; own-device approval card messages | Console task trace view; sync fixes found in rehearsal; demo data reset script |
| 4 · 6–10 Dec | Routing only inside a household; the 1,000-attempt isolation suite | Invites, members, roles; console household and device lookup |
| 5 · 13–17 Dec | Approval routing by role; signed decisions; expiry | Audit trail storage; reminder pushes; console audit view |
| 6 · 20–24 Dec | Admitting a new device (key wrapping) | Attachments in object storage; shared household threads; journal upload |
| 7 · 27–31 Dec | Recipe package signing and staged rollout | Metrics, alerts, backups; export and deletion; console alerts and rollout controls |
| 8 · 3–7 Jan | Threat-model review; load test | Runbook; staging and production split; console security review |

**Where they meet:**

- **Contracts.** A owns the protocol and `backend.v1.yaml`; B proposes changes in a pull request, and A approves. The week plan’s Monday 16:00 freeze applies to both.
- **Sync and keys.** B builds sync, but A’s key model decides what B stores. Agree the key model by Thu 19 Nov, before B starts sync.
- **Tasks and the trace view.** A emits a trace event at each task step; B’s console reads them. Fix the event fields in week 2.
- **Reviews.** Every pull request gets the other person’s review within one working day. That way either can cover the other’s lane for a few days.

The demo week is the tightest for A. If week 3 slips, move the PC → phone direction to B for the last two days; it reuses the same task messages.
