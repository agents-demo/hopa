# ADR-0020 - Android is the active client; Windows is next; Harmony is frozen

- Status: accepted
- Date: 2026-11-13
- Relates to: ADR-0016 (clients own the loop), ADR-0018 (shared data),
  ADR-0019 (offline promise)

## Context

Three clients share one contract: HarmonyOS (shipped), Android (planned) and
Windows (planned). The owner's priority has moved: Harmony development is no
longer interesting. **Android is the active client; Windows is the next one.**

Keeping Harmony on the active path has a cost: its UI debts, its contract
divergence and its tests compete with Android for the same time, and most of
them do not affect Android or Windows.

## Decision

- **Android is the only client under active development** until it reaches the
  parity and release gates in `docs/project/plan/android/`.
- **Windows is the next client after Android.** It consumes the same contracts,
  fixtures and shared data; its stack (shared Kotlin core or its own) is decided
  when Android ships, not now.
- **Harmony is frozen**:
  - no new features, no UI refactors, no test backfill;
  - generated data (catalogue, policy, prompt rules) still updates it, and CI
    still builds it, so it does not rot silently;
  - security fixes still land if a shipped Harmony build is affected;
  - it is not the next client and has no scheduled revival.
- **Conformance fixtures are mandatory for Android, Windows and every new
  client.** Harmony is a **recorded legacy exception** (ADR-0016 is superseded
  in this part) until someone writes an adapter; that adapter is explicitly out
  of scope while Harmony is frozen. This is an exception, not an unnoticed gap.
- **The Android plan is the active delivery plan.** The refactor plan stays as
  history; Harmony debts move to `docs/project/status.md` as deferred, not as
  prerequisites.
- **Shared work is untouched**: the bridge, its `adb` transport, the contracts
  and the data generators serve Android first and remain client-neutral.

## Consequences

- Starting Android no longer waits for Harmony's redaction, hash chain,
  tombstones, UI tests or file splits.
- Windows can reuse `core`/contracts/data if the stack decision favours it; the
  shared data is already platform-neutral.
- A Harmony security or data-loss bug is a maintenance ticket, not a roadmap
  item; it is fixed when a build ships or when it blocks a demo.
- The platform matrix marks Harmony as frozen and its conformance row as a
  legacy exception; Windows is marked as next.
- If Harmony is ever revived, its first task is the contract adapter and the
  six fixtures, not new features.
- Evals and the platform dimension start with Android; Windows joins later.

## Alternatives considered

- **Harmony next.** Rejected: not interesting to the owner and not where the
  product is going.
- **Maintain all three in parallel.** Rejected: splits focus and delays the
  client that matters now.
- **Delete Harmony.** Rejected: it is the shipped reference and the source of
  the behavioural knowledge Android is rebuilding.
- **Build Windows before Android.** Rejected: Android has the harder device
  seam and the existing behaviour to match; Windows is simpler once the
  contracts and fixtures are proven.
- **Make Android a thin client of a backend.** Rejected in ADR-0016; Android
  runs the loop itself.
- **Silently skip the Harmony fixtures.** Rejected: an exception must be
  written down or the contract claim is false.
