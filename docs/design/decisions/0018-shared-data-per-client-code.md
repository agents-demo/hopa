# ADR-0018 - Share the data and the fixtures, not the loop

- Status: accepted
- Date: 2026-11-13
- Relates to: ADR-0016 (each client owns its loop), ADR-0017 (Android dual execution)

## Context

ADR-0016 accepts three loop implementations and pins their behaviour with
`contracts/fixtures`. That covers what a step does, but not the **data** a step
reads: the app catalogue, the payment vocabulary, the prompt rules, the routing
rules and the observation hash. Each of those lived in ArkTS code, and the
Android client would have copied it.

The app catalogue was already authored in `services/brain/knowledge/` and
generated into the app, but every entry was `platform: harmonyos` with a
HarmonyOS `bundle`, and the generator emitted only ArkTS. Android would have
forked 35 descriptions.

## Decision

- **Data lives once, in `contracts/`.** A client may render it into code at
  build time; it does not re-author it.
- Shared files:
  - `contracts/catalog/catalog.v1.json` — app and site ids, names, aliases,
    purposes, actions, and a `platforms` map with launch details;
  - `contracts/policy/approval.v1.json` — payment/sensitive/allowed kinds, the
    payment words and action labels, the amount regexes, merchant prefixes;
  - `contracts/prompts/rules.v1.json` — the promises a system prompt must keep,
    as phrases a client test asserts;
  - `contracts/fixtures/routing.json` — lexical routing cases;
  - `contracts/fixtures/observation-hash.json` and
    `contracts/observation/limits.v1.json` — the hash vector and the caps.
- **Rendering is generated and committed.** `tools/scripts/build-app-catalog.py`,
  `build-policy-data.py` and `build-prompt-rules.py` emit ArkTS today and Kotlin
  for Android (the catalogue renderer already does); CI runs each with
  `--check`, so a stale copy fails the build.
- **The loop, the parser and the gate stay per client.** This ADR moves
  vocabularies and cases, not orchestration. `ApprovalPolicy` still decides; it
  reads its lists from generated data.
- **The prompt is the exception, deliberately.** The Harmony prompt text is not
  rewritten by this ADR: changing it changes model behaviour, which is not a
  pure refactor. The contract pins the rules and a client test proves the
  rendered prompt carries them; wording and platform blocks stay local.
- **Legacy names are recorded, not hidden.** The Harmony parser still emits
  `ui.sendMessage`, `ui.call`, `a11y.observe` and `sandbox.runNetworked`, which
  the action schema does not list. The policy data contains them; the Android
  client uses the schema names (`system.sendMessage`, `system.call`).

## Consequences

- A new app is described once in `services/brain/knowledge/`; the catalogue,
  the ArkTS copy and the future Kotlin copy are generated together.
- Adding a payment word or a sensitive kind is a contract change with a test, not
  a three-place edit.
- The Android client consumes the same data, so a Launchpad entry cannot mean
  one thing on Harmony and another on Android.
- The conformance fixtures now have siblings: routing and observation hash.
  A behaviour change that cannot be expressed there is a client bug.
- The catalogue's Kotlin output has no committed consumer until Android A0/A11;
  the renderer is tested so that step is mechanical.
- `services/brain` remains a deterministic routing service; it is not the
  contract and its old `Prompts.kt` (`finish` kind) is not a reference.

## Alternatives considered

- **Move the catalogue to a runtime backend call.** Rejected: the phone must
  work offline, and the catalogue is static data.
- **Keep ArkTS as the source and generate Android from it.** Rejected: it makes
  Harmony the owner of every platform's data and keeps Harmony bundles in the
  neutral file.
- **Share the loop as a library.** Rejected earlier (ADR-0016); this ADR does
  not reopen it.
- **Rewrite the prompt now.** Rejected as a refactor: prompt edits need an
  evaluation, not a commit that also moves files.
