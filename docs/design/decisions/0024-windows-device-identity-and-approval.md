# ADR-0024 — Device identity and approval provenance for the Windows client

- Status: accepted
- Date: 2026-11-17, revised 2026-11-17 for the backend gateway
- Owners: Windows lead (TBD)
- Relates to: ADR-0016 (clients own the loop), ADR-0020 (Android is the active
  client), ADR-0021 (Windows client stack), ADR-0022 (backend language and
  shape), P4 of `docs/project/plan/windows/README.md`

## Context

P4 makes the Android phone a peer of the Windows client: a PC action can push an
approval request to the phone, receive allow or deny, and return a verified
result. The original plan said to reuse the bridge/relay and add device
identity. Upstream has since built `services/backend` (ADR-0022): a Ktor
gateway with a durable task state machine, QR pairing, opaque per-device tokens
and server-set device identity, and an explicit plan to move clients from the
relay to the gateway. The user's direction is that **phone and PC talk through
that backend**. This ADR is revised accordingly; the relay is no longer the
target.

Three facts of the gateway contract shape the decision:

1. **Identity comes from the access token, not the wire.** The gateway envelope
   has no `household` field; `from` is server-set and a client-supplied value is
   ignored (`gateway.v1.schema.json:44–51`, `Envelope.kt:7–12`). Device identity
   is `deviceId = dev_<uuid>` plus `platform = android | windows`
   (`PairingService.kt`, `AuthPort.kt`).
2. **Tasks have a durable state machine and fixed message types.** States are
   `queued`, `delivered`, `acked`, `progress`, `done`, `failed`, `cancelled`
   (`TaskRouter.kt:215–221`); the only client task messages are `task.create`,
   `task.ack`, `task.progress`, `task.result`, `task.error`, `task.cancel`
   (`gateway.v1.schema.json:19–32`). `task.needs_approval` is reserved and
   refused with `E_UNSUPPORTED` until backend week 5.
3. **A credential is still not an identity.** The old relay's rotating paired
   token and the gateway's opaque access token both identify a *device* only
   because the server resolves the token. A client cannot safely name another
   device; a shared token would still let the PC answer as the phone.

The product invariant is unchanged: **a payment requires the user's approval and
cannot be done without it.** The loop already denies missing, late or malformed
answers and forbids pre-approval. Once approval travels over the backend, the
gate must also know *who* answered — an `allow` the PC sent itself is not the
user's approval even if its shape is valid.

## Decision

- **Windows pairs its own credential through the backend QR pairing**, declaring
  `platform = "windows"` and its own key. It never reads, pastes or reuses the
  phone's token, and it does not use the legacy relay for P4. The existing
  Windows Credential Manager path may hold the resulting token pair; the host
  sends it to the sidecar in memory as before (ADR-0021).
- **The gateway is authoritative for task state.** The sidecar keeps only a
  local *view* of tasks, derived from gateway messages. Its states and event
  names are the gateway's: `queued → delivered → acked → progress →
  done|failed|cancelled`, driven by `task.create/ack/progress/result/error/
  cancel`. The Windows IPC messages (`task.start/get/handoff` plus the new
  `task.event`) are the host↔sidecar seam; the host maps them to and from the
  gateway envelope. The frozen IPC shape is a projection, not a second state
  machine.
- **Identity is explicit and server-derived.** On the wire, identity is the
  backend's `deviceId` and `platform`; the host sets the sidecar's
  `approval.result.device` from the authenticated gateway `from`, never from a
  client-supplied value. The run record keeps the stable local label
  `approver.device = "pc" | "phone"`; it maps to the gateway as
  `windows → pc`, `android → phone`. A claim that cannot be backed by the
  authenticated sender is refused.
- **Approval provenance stays in the device gate.** `ActionExecutor` asks once,
  before any tier runs, and writes `approver` on the record. The backend
  transports and attributes; it never decides. `task.needs_approval` is reserved
  until backend week 5, so until then the Windows client does not claim a phone
  approval over the gateway — it uses the local gate and fails closed when an
  answer claims a device no link could have supplied.
- **A dropped link fails the task with a readable error** and leaves the
  conversation intact. No task is silently marked done.
- A threat-model entry covering forged approval and device impersonation is
  part of the same work (`docs/reference/threat-model.md`).

## Consequences

- One transport and one task model: the backend's gateway. No compatibility
  shim for the relay is built into P4; the relay keeps running unchanged for
  other clients until they move.
- Task state is durable in Postgres. The sidecar's in-memory view can be
  rebuilt from gateway events and is never the authority.
- Approval over the gateway is gated on backend week 5 (`task.needs_approval`
  and signed device-key decisions). P4's first slice can land against the
  gateway task contract now; the "approved on the phone" checkbox stays open
  until that backend capability exists.
- The approval identity changes vocabulary at the wire boundary only
  (`platform`/`deviceId` → `pc`/`phone`), so the run-record schema stays stable.
- The host must set `approval.result.device` from the authenticated gateway
  identity. A client that can set that field itself would defeat the rule; the
  sidecar refuses a phone claim when no link is attached as a stopgap.
- The backend's week-5 signed decisions give stronger provenance than transport
  attribution alone. That is the intended upgrade, not a replacement for these
  rules.

## Alternatives considered

- **Keep the relay and add an approval endpoint there.** Rejected: upstream is
  explicitly moving clients to the gateway with no relay compatibility, and the
  relay has no durable task store or per-device identity.
- **Reuse the phone's token.** Rejected. A shared credential cannot distinguish
  the two ends of a conversation, so the PC could return its own approval and
  the gate could not tell it from the user's.
- **Let the backend decide approvals.** Rejected: it would move the gate out of
  `packages/core` and contradict ADR-0016/ADR-0021. Week 5's backend design also
  keeps the gate on the acting device.
- **Model a second task state machine in the sidecar.** Rejected: it would drift
  from the gateway's states and message types; the sidecar now holds a local
  view only.
