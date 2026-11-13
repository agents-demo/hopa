# ADR-0016 - Each client owns its agent loop

- Status: accepted
- Date: 2026-11-13
- Supersedes: ADR-0011 **in part** (the claim that the loop must be server-side)

## Context

ADR-0011 said the loop is a server concern and clients should be thin. That
remains a valid *server* mode, but it is not the product direction: the APK must
work as a full assistant on the phone, and Windows must work on the PC, without a
backend account or a network service owned by us.

Running the loop in the client means each platform re-implements orchestration.
That is accepted, but unmanaged duplication would let the three behaviours drift.

## Decision

- **Each client owns its loop**: HarmonyOS (ArkTS, today), Android (Kotlin), and
  Windows (stack decided separately).
- The **contract is shared, the loop is not**. The shared artefacts are:
  - `contracts/schemas/` (observation, action, decision, run-record);
  - `contracts/fixtures/` (conformance cases every implementation must pass);
  - the policy semantics (what is `read`, `sensitive`, `payment`; when to ask);
  - the bridge protocol for cross-device control and chat sync.
- A client may be **thin** when it points at a backend; that is a deployment
  option, not the architecture. `services/backend` remains planned for the hosted
  mode (ADR-0011), and stops being a prerequisite for clients.
- Model keys are held by the client (Android Keystore, Windows DPAPI, Harmony
  HUKS/Asset Store); no key ships in the repository or in the APK.

## Consequences

- Three loop implementations must pass the **same** conformance fixtures; a
  fixture is the only way a behaviour change is allowed to land in all clients.
- The evaluation suite (`services/evals`) gains a platform dimension; it measures
  a client, not "the loop".
- A backend, when it exists, runs the same contracts and can be swapped in for a
  client loop without changing the contract.
- Divergence in prompts, gating or record chaining is a bug, not a style choice.

## Alternatives considered

- **One shared loop in Rust/C++ with FFI.** Rejected for now: one implementation,
  but three build systems and FFI debugging; revisit if the three diverge in ways
  fixtures cannot hold.
- **Server-only loop.** Rejected: requires an account and a backend the product
  does not have, and the APK must work offline for its core promise.
- **Copy one client's loop into the others.** Rejected: copying without the
  conformance suite is exactly how behaviour drifts.
