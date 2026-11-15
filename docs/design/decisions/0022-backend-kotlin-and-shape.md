# ADR-0022 - Backend language and shape: Kotlin on the JVM, one build with `packages/`

- Status: proposed
- Date: 2026-11-15
- Owners: Amir (lane A), Batya (lane B)
- Relates to: ADR-0011 (what a backend owns), ADR-0016 (clients own the loop),
  ADR-0018 (share the data, not the loop), ADR-0021 (Windows sidecar precedent)

## Context

`services/backend` is about to stop being a README. Week 1 of the backend plan
needs a WebSocket gateway, a Postgres schema with `household_id` on every table,
QR pairing, trace ids and FCM wake-up, built by two engineers in five days and
maintained for at least a year.

The choice of language was weighed against what the repository already holds,
not against general taste:

- The clients are **Kotlin** (Android) and **.NET over a Kotlin sidecar**
  (Windows). `packages/core` (2,659 lines) and `packages/data` (229 lines) are
  pure JVM Kotlin with no Android imports, enforced by
  `packages/core/build.gradle.kts` and CI.
- Those packages already implement the pieces hardest to keep in sync: the
  approval gate and classifier, the run-record chain and factory, the decision
  parser, the observation hasher, the loop, and `ConversationStore` with the
  dedupe, last-writer-wins title and tombstone rules the weekly plan asks sync to
  preserve.
- `apps/windows/sidecar` already builds those packages in its **own** Gradle
  build, so a second non-Android JVM deployable is an established pattern.
- CI already runs JDK 17, Gradle and ktlint.
- The existing services are Python standard library, and `services/wire` carries
  a hand-rolled RFC 6455 WebSocket only because Render ran `pip install --no-deps`
  on a free tier. The gateway does not inherit that constraint.
- Scale target is small: 1,000 households, 5,000 sockets, one EU region.

## Decision

1. **Kotlin 2.0.21 on the JVM, Ktor 3.0.3** (Netty, WebSockets, content
   negotiation), kotlinx.serialization, `jvmToolchain(17)`; JDK 21 may run Gradle
   and the deployed JRE. Ktor is pinned to 3.0.3 because it is the release
   compiled with Kotlin 2.0.21, the version the shared catalog already uses; no
   second Kotlin toolchain enters the repository.
2. **One Gradle build under `services/backend` that includes `:core` and `:data`
   from `packages/`**, the way `apps/windows/sidecar` does. The backend imports
   the gate, records, contracts and session rules rather than re-deriving them
   from JSON.
3. **Postgres is the queue and the record.** A task is a row with a state
   machine, not an in-memory map; Redis is not introduced for presence in v1.
4. **Row-level security on every tenant table**, with the household set per
   transaction, so a missing `where` clause cannot leak another family's rows.
5. **Opaque access tokens, hashed at rest** (15 min) and rotating refresh tokens
   (30 days), so a revoked device is cut off immediately rather than at JWT
   expiry.
6. **Contract-first**: `contracts/openapi/backend.v1.yaml`,
   `contracts/schemas/gateway.v1.schema.json` and
   `contracts/fixtures/gateway-v0.json` are written and frozen before the first
   handler, and both the Kotlin codec and a Python checker replay the fixtures.
7. **The server never sees a device command.** It carries task messages only; no
   `adb`, `hdc`, UI Automation or screen content enters this codebase.

## Consequences

- The gate, records and session semantics have one implementation each, which is
  the property ADR-0016 and ADR-0018 were written to protect.
- A hosted loop (a future function in the weekly plan) can wrap `AgentLoop`
  instead of porting it.
- The backend team needs JVM operations skill (JFR, heap sizing, jlink) and Ktor
  knowledge; neither exists in the team today, and that is the main cost.
- A JVM process costs more memory idle than a Go binary; the target is a 512 MB
  container, measured in the week-1 evidence file.
- Two Gradle builds (Android, backend) must both stay green; CI gains one job.
- If `packages/` ever needs to run on iOS, Kotlin Multiplatform is the natural
  continuation rather than a rewrite.

## Alternatives considered

- **Go.** Better operations story: one static binary, smaller memory, first-class
  `pgx`/`sqlc` and WebSocket ergonomics, and easier backend hiring. Rejected
  because every shared behaviour above becomes a second implementation validated
  only by fixtures, which is exactly the drift ADR-0016 warns about. It is the
  right answer if the backend owner is a Go developer and the team prefers
  hiring backend engineers to Android ones.
- **Rust.** Fastest and safest at the margin, but the 5,000-socket target does
  not need it, neither engineer writes Rust, and it carries the same duplication
  cost as Go with slower iteration inside an eight-week plan.
- **Python.** Fastest to the first demo and consistent with `services/bridge`
  and `services/evals`, but it adds a third language family for the same
  contract, cannot reuse the Kotlin gate or records, and leans on dynamic typing
  exactly where the task state machine and token handling need rigor. It remains
  the pragmatic fallback if the demo date becomes the binding constraint.
