# ADR-0001 — Brain hosting: JVM service first, ArkTS later

- Status: accepted
- Date: 2026-11-05

## Context

Mika's decision core is pure Kotlin (387 files). Reimplementing it in ArkTS
before the loop is proven would delay every safety and bench result. The
HarmonyOS app cannot host a JVM, but the PC harness can.

## Decision

1. **M1–M2:** run the loop on the PC. The reference implementation is Python
   (`agent/`); the Mika Kotlin brain is extracted into a standalone JVM service
   with no `android.*` imports and an HTTP `POST /decide` contract.
2. **M3+:** port the same contract to ArkTS in `app/core`. The JVM service
   becomes optional behind a feature flag.
3. Both implementations share one JSON contract and one golden-file corpus
   (`schemas/`, `schemas/fixtures/`).

## Consequences

- The phone app is ArkTS only; no JVM, no Python, no `proot`.
- The PC harness is a first-class deliverable, not a throwaway.
- Two implementations must be kept in parity; contract tests are mandatory.
- `docs/port-log.md` records every ported module.

## Alternatives considered

- ArkTS first: slower, no safety evidence until the ACL exists.
- Ship the JVM inside the app: impossible on HarmonyOS Next.
