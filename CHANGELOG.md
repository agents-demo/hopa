# Changelog

All notable changes are recorded here. Versions follow `docs/versioning.md`.

## Unreleased

### Added

- Bridge token rotation: `/pair` returns an access token plus a refresh token
  and `expires_in`; every pair or refresh rotates both. The phone stores the
  pair in Asset Store and renews silently when a request comes back
  `401 token expired`.
- The 2in1 shell drives its own machine through a second `pc-agent bridge`
  (port 8767, `rport` restored by `deploy.ps1`): observe, screenshot, tap,
  type, swipe, key and launch, registered as the shared `RemoteUiCapability`,
  with the bridge as its screen source. Settings gains a **PC bridge** section
  that reports `Connected.` only after a real `/health` answer.
- The laptop approval card shows the last frame the bridge captured, labelled
  **WHAT HOPA SAW**, so the consent is given against evidence rather than a
  description.
- The bridge also persists the conversation snapshot, and the phone pushes it
  once at boot, so a restarted bridge no longer leaves the laptop's "From your
  phone" list empty. When the list is empty the laptop now says why (key
  rejected, or nothing pushed yet) instead of showing nothing.
- The bridge persists its token pair and read-only sessions key in
  `~/.hopa/bridge-<port>.json`, so a restart inside the TTL no longer forces a
  re-pair (`--state`, `--no-state`). `tools\scripts\bridges.ps1` starts,
  reports or stops one bridge per device (8766 phone, 8767 2in1) and
  `deploy.ps1` calls it.
- The 2in1 package is now honest about its target: `2in1` and `tablet` only,
  a laptop-bodied launcher icon in the module, and a 960x620 minimum window so
  the sidebar, rail and composer cannot be crushed.

## 0.1.0 — 2026-11-06

### Added

- PC reference loop: observe → decide → gate → act → verify → record.
- v1 JSON schemas for observation, action, decision and run record.
- Payment classification from the screen, never from a model flag.
- Emergency-number block, password/OTP typing refusal, URL policy, rate limits
  and per-task tool allow-lists.
- Hash-chained, redacted run records with `verify-chain`.
- OpenAI-compatible client with retry and one repair attempt.
- Kotlin brain: lexical router, `ChannelAdvisor`, `/decide`, sessions, `/knowledge`.
- 12 HarmonyOS system app knowledge files with a strict front-matter loader.
- Prompt contract with intent gate, channel order and truncation.
- 20 HOPA-Bench task definitions and a report aggregator.
- ArkTS screen-aware approval policy and an observation-fed `AgentLoop`.
- ADRs 0001–0006, contracts, threat model, privacy, safety and status docs.
- CI: Python tests, ruff, plan lint, Kotlin build and contract test.

### Known limitations

- The HAP is unsigned.
- The accessibility extension is not declared; no ACL has been filed.
- The entry UI is still a shell.
- No device bench or real-model run has been recorded.
- API 26 is not installed; the local build uses API 24.
