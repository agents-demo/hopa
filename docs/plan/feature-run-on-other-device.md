# Run on the other device — plan

## Goal

A turn can name its **target**: this laptop or the phone. Both directions, with
the same vocabulary, evidence and consent rules. A laptop question like "open
Settings" should be able to act on the phone, and a phone question should be
able to act on the laptop — visibly, never by guessing.

## Where things stand

- The pooled bridge already routes by target: `X-Hopa-Role: phone|2in1` or
  `/d/<serial>/…` (`bridge_pool.resolve`).
- Each shell's `BridgeClient` is configured once with **its own** role, so
  actions always land on the machine that asked.
- `RunRecord` has `turnId` but no target; the turn meta carries
  `⟦meta⟧steps/shot/shotId` but no target either.
- The pane cannot say "on your phone"; the chat cannot show which machine ran.

## The one hard problem: authorisation across devices

`_PoolHandler._forward` passes the caller's `Authorization` verbatim to the
target node, and that node validates it against **its own** token. So a laptop
token (`hopalaptop`) asking for `role=phone` is rejected by the phone node.

Decision: the pool is the trust boundary. It already authenticates the caller
with `authorized_any`; when the resolved node is not the caller's own, it must
forward using **the target node's token**. Two consequences to make explicit:

1. Pairing one device grants control of every device in the pool. That is the
   intended household model, and it must be written in `docs/guides/pc-bridge.md`.
2. The pool must resolve *before* authenticating, so a caller can only reach
   devices it is allowed to see; a later `allow_remote=false` per device is a
   one-line policy hook if it is ever needed.

## Design

1. **Turn meta:** the initiating runtime writes `target=phone|2in1` into
   `⟦meta⟧`. Both shells read it with `ChatFormat.metaValue`; it travels with
   the text, so no schema change to `/chats`.
2. **Run record:** `RunRecord.targetRole` is set when the record is created. The
   pane labels a run `Ran on your phone` / `Ran on this laptop`; the chat card
   says the same. Never infer it from timing.
3. **Client:** `BridgeClient` keeps its configured role but every call accepts
   an optional role override; `RemoteUiCapability` gets `targetRole` from the
   runtime instead of baking it in.
4. **Runtime:** `AgentRuntime` takes a `target` for the run, passes it to the
   capability, and stamps it into the meta. One hop only: a run never bounces
   from the phone back to the laptop.
5. **Evidence:** the step screenshot is taken **from the target** (same role
   override), and goes through the existing image store, so both shells can show
   the frame with its `shotId`.
6. **UI — composer:** a quiet two-state chip beside the input, `This laptop ⇄
   Phone`, shown only when `/health` lists the other role. Offline → disabled
   with the reason. The choice persists per shell.
7. **UI — consent:** the approval card names the device it will act on, in one
   line, before the buttons. Payment rules do not change.
8. **Phone shell:** the same chip, mirrored (`This phone ⇄ Laptop`), so the
   feature is symmetric rather than a laptop-only privilege.

## Phases

| # | Work | Effort |
|---|---|---|
| 1 | Pool: authenticate caller, forward with the target node's token; tests for cross-role tap/screenshot/launch; document the trust model | 0.5 d |
| 2 | Client + runtime target plumbing (role override, `RemoteUiCapability.targetRole`, screenshot role) | 0.5 d |
| 3 | Meta `target=`, `RunRecord.targetRole`, pane/chat labels | 0.25 d |
| 4 | Composer chip with availability, persisted choice, approval line | 0.5 d |
| 5 | Phone-side mirror of the chip | 0.25 d |
| 6 | Device verification both ways (laptop opens an app on the phone; phone opens an app on the laptop), including evidence and the locked-phone case | 0.5 d |

**Total ≈ 2.5 d**, of which ~1.25 d is the shared core (1–3).

## Edge cases to handle honestly

- **Other role offline:** chip disabled with `phone not paired`, not a dead tap.
- **Locked phone:** taps may be refused by the lock screen. Report that plainly
  ("the phone is locked") rather than a generic failure; never fake success.
- **Old runs:** no `targetRole` → say "on this device" only when the turn's own
  shell can prove it; otherwise say nothing.
- **Approval:** the device name is part of the consent text; a payment gate on
  the phone behaves exactly as on the laptop.
- **Recursion:** one hop. A phone-targeted run cannot itself ask the laptop.
- **Chat sync:** the target is part of the text meta, so a turn keeps its
  meaning on the other shell without a `/chats` migration.

## Acceptance

- From the laptop: `Open Settings on the phone` launches Settings **on the
  phone**, the pane shows `Ran on your phone` with the step and a frame of the
  phone screen, and the phone's own chat shows the same turn.
- From the phone: the mirrored case opens an app on the laptop and the laptop's
  pane shows it.
- With the other device offline, the chip is disabled and no request is sent.
- With the other device locked, the answer says so and takes no action.
