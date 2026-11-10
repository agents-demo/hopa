# Changelog

All notable changes are recorded here. Versions follow `docs/versioning.md`.

## Unreleased

### Added

- Bridge token rotation: `/pair` returns an access token plus a refresh token
  and `expires_in`; every pair or refresh rotates both. The phone stores the
  pair in Asset Store and renews silently when a request comes back
  `401 token expired`.

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
