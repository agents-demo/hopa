# ADR-0028 — Windows modernization: .NET 10 and schema-first frames

- Status: accepted
- Date: 2026-11-24
- Owners: Windows lead

## Context

ADR-0021 chose .NET 8 + WPF and newline-delimited JSON for the first Windows
release. That release now exists as the P0-P6/W7-W11 work, but two assumptions
aged badly:

1. .NET 8 LTS ended on 2026-11-10. The shipped MSI is self-contained, so users
   run an unsupported runtime today.
2. The NDJSON frames are hand-written on both sides. C# reads dynamic
   `JsonObject` keys and Kotlin has a 392-line `Protocol.kt` builder file. The
   protocol.md, code and tests can drift independently.

The repository already uses Kotlin 2.4.21, AGP 9.5.1 and Gradle 9.6.0. The
sidecar shares the Android version catalog and `core/**` modules, so a Kotlin
upgrade cannot be separated from Android. The Gradle toolchain is 17; the
shipped sidecar runtime is a separate concern.

## Decision

- Move every Windows project to **.NET 10 LTS**, self-contained. The previous
  **signed MSI** is the rollback; .NET 8 is not kept as a fallback.
- Treat **Kotlin 2.4.x** as the single compiler baseline. Keep the Gradle
  `jvmToolchain(17)` for Android bytecode; ship a **JDK 21** jlink runtime for
  the sidecar. Do not adopt JDK 25 without a product reason.
- Keep **NDJSON v1** on the wire. Define payloads with **JSON Schema**, capture
  golden frames from the current build, and validate both ends in tests.
- Do **not** adopt Protobuf: the protocol has open `op` unions, explicit nulls
  and a deterministic run-record hash chain that a second canonicalisation
  would put at risk.
- Code generation from the schema is conditional: only after a measured drift
  problem. Validation and golden tests come first.
- Use Central Package Management and lock files for the .NET build.

## Consequences

- Users stay on a supported runtime without installing .NET.
- The host and sidecar are co-shipped; version handling is a readable hard
  failure, not a compatibility matrix.
- Schema changes must preserve the run-record hash chain and stored data.
- ADR-0021 is superseded in part: the stack stays WPF/.NET + Kotlin sidecar,
  but the runtime version and the IPC evolution change.

## Alternatives considered

- **Stay on .NET 8:** rejected; EOL before the next release window.
- **Port the loop to .NET:** rejected again; a second brain and gate.
- **Protobuf:** rejected for open unions, nulls and the hash chain.
- **JDK 25 runtime:** rejected for image size with no product value.
