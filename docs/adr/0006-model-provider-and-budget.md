# ADR-0006 — Model provider, transport and budget

- Status: accepted
- Date: 2026-11-05

## Context

The loop needs one model call per step. Providers differ in price, latency,
data residency and safety filters. The app must not be locked to one vendor.

## Decision

- The transport is **OpenAI-compatible** `POST /chat/completions`.
- The provider is a deployment setting, not a code change.
- The key lives in an environment variable on the PC and in HUKS on device. It
  is never written to a record, a log or git.
- A fallback list is configured; a failed primary moves to the next entry.
- Per-task and per-day cost caps are enforced by the loop.
- Default targets: p95 step latency ≤ 8 s, cost per task recorded in
  `docs/bench-v0.md`, and a hard stop at the task budget.

## Consequences

- Any compatible provider works, including a local gateway.
- Prompt caching is provider-specific and is measured, not assumed.
- Data residency is a provider choice recorded in the privacy note.

## Alternatives considered

- Vendor SDK: larger dependency, weaker portability.
- On-device model only: not good enough for the first release.
