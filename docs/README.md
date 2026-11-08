# HOPA documentation

The docs are grouped by what they answer. Pick the section, then the file.

## Architecture

| File | Question |
|---|---|
| [overview.md](architecture/overview.md) | What is HOPA made of? |
| [layers.md](architecture/layers.md) | What may import what? |
| [data-flow.md](architecture/data-flow.md) | How does one goal become an action? |
| [target-structure.md](architecture/target-structure.md) | Where is the code going, and why? |
| [adr/](adr/README.md) | Why was a decision made? One ADR per decision. |

## Guides

| File | Question |
|---|---|
| [setup.md](guides/setup.md) | How do I build and run it? |
| [build-and-sign.md](guides/build-and-sign.md) | How is the HAP signed and installed? |
| [device-testing.md](guides/device-testing.md) | How do I test on the emulator or a phone? |
| [pc-bridge.md](guides/pc-bridge.md) | How does the PC-tethered control work? |

## Reference

| File | Question |
|---|---|
| [contracts/](contracts/observation.md) | What are the observation, action and error contracts? |
| [protocols](guides/pc-bridge.md) | Which HTTP and MCP endpoints exist? |
| [bundles.md](reference/bundles.md) | Which HarmonyOS bundle belongs to which app? |
| [knowledge.md](reference/knowledge.md) | How is app/site knowledge written? |
| [skills.md](reference/skills.md) | How are skills written? |
| [safety.md](reference/safety.md) | What is the approval model? |
| [threat-model.md](reference/threat-model.md) | What are the security limits? |
| [privacy.md](reference/privacy.md) | What data is stored? |
| [abuse.md](reference/abuse.md) | What is explicitly refused? |
| [glossary.md](reference/glossary.md) | What do the words mean? |

## Product

| File | Question |
|---|---|
| [coverage.md](product/coverage.md) | What works today, and what is blocked? |
| [roadmap.md](product/roadmap.md) | What comes next? |
| [ux.md](product/ux.md) | What is the intended experience? |
| [bench.md](product/bench.md) | How is the agent evaluated? |
| [bench-results-v0.md](product/bench-results-v0.md) | What did the first bench run show? |

## Operations

| File | Question |
|---|---|
| [release.md](operations/release.md) | How is a release cut? |
| [versioning.md](operations/versioning.md) | How are versions numbered? |
| [owners.md](operations/owners.md) | Who owns what? |
| [acl-request.md](operations/acl-request.md) | What is in the Huawei ACL request? |
| [definition-of-ready.md](operations/definition-of-ready.md) | When may a phase start? |
| [sbom.json](operations/sbom.json) | What ships in the HAP? |

## Plan

| File | Question |
|---|---|
| [plan/README.md](plan/README.md) | How the plan is scored and used |
| [plan/phase-*.md](plan/README.md) | One file per phase |
| [plan/appendix-*.md](plan/README.md) | Port matrix, bench, contracts, audit log |

## History

| File | Question |
|---|---|
| [status-2026-11-07.md](history/status-2026-11-07.md) | What was true on that day? |
| [baseline-2026-11-06.md](history/baseline-2026-11-06.md) | What machine and SDK was the baseline? |
| [emulator-crash-2026-11-06.md](history/emulator-crash-2026-11-06.md) | What broke, and how? |
| [port-log.md](history/port-log.md) | What ideas were reused? |
| [knowledge-triage.md](history/knowledge-triage.md) | How is the app catalogue classified? |

`history/` is a log. Current state lives in `history/status-*.md` only until the
next snapshot replaces it; architecture and reference are the stable docs.
