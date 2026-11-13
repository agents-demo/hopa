# HOPA app documentation

This folder documents the **HarmonyOS app** and the product around it. A few
documents here are *shared* with the services because both halves read them
(contracts, safety, the architecture map); everything that belongs to a service
lives in [`services/docs/`](../services/docs/README.md) and is not repeated here.

## Start here

| File | Question |
|---|---|
| [guides/setup.md](guides/setup.md) | How do I build and run the app? |
| [guides/build-and-sign.md](guides/build-and-sign.md) | How is the HAP signed and installed? |
| [guides/install-phone.md](guides/install-phone.md) | How does the app reach a phone? |
| [guides/acl-request.md](guides/acl-request.md) | How is the accessibility ACL requested? |
| [product/ux.md](product/ux.md) | What is the intended experience? |

## What the app can do

| File | Question |
|---|---|
| [product/coverage.md](product/coverage.md) | What works today, and what is blocked? |
| [product/roadmap.md](product/roadmap.md) | What comes next? |

## The app inside

| File | Question |
|---|---|
| [architecture/overview.md](architecture/overview.md) | What is the app made of? |
| [architecture/layers.md](architecture/layers.md) | What may the app's layers import? |
| [architecture/data-flow.md](architecture/data-flow.md) | How does one goal become an action? |
| [architecture/target-structure.md](architecture/target-structure.md) | The historical audit that produced the current folders |

The app's modules are `apps/harmony`: `core` (loop, gate, records), `capabilities`
(accessibility, browser, llm, sandbox, system), `app` (shared kit), `phone` and
`laptop` (the two shells).

## Shared with the services

These describe both halves, so they stay here rather than in either hemisphere:

| File | Question |
|---|---|
| [contracts/](contracts/observation.md) | Observation, action and error contracts |
| [reference/bundles.md](reference/bundles.md) | Which HarmonyOS bundle is which app? |
| [reference/safety.md](reference/safety.md) | What is the approval model? |
| [reference/threat-model.md](reference/threat-model.md) | What are the security limits? |
| [reference/privacy.md](reference/privacy.md) | What data is stored? |
| [reference/abuse.md](reference/abuse.md) | What is explicitly refused? |
| [reference/glossary.md](reference/glossary.md) | What do the words mean? |

## Decisions

[adr/](adr/README.md) — one file per decision. Read ADR-0007 (taxonomy), ADR-0008
(renames) and ADR-0011 (loop ownership) first. The service decisions (0009, 0010,
0012, 0013) are indexed there and live in
[`services/docs/adr/`](../services/docs/adr/).

## Running and releasing

| Folder | Question |
|---|---|
| [operations/release.md](operations/release.md) | How is a release cut? |
| [operations/versioning.md](operations/versioning.md) | How are versions numbered? |
| [operations/owners.md](operations/owners.md) | Who owns what? |
| [operations/definition-of-ready.md](operations/definition-of-ready.md) | When may a phase start? |
| [operations/sbom.json](operations/sbom.json) | What ships in the HAP? |
| [operations/acl-request.md](operations/acl-request.md) | What is in the Huawei ACL request? |

## Plan, status, history

| Folder | Question |
|---|---|
| [plan/refactor/README.md](plan/refactor/README.md) | The active structural refactor, with evidence |
| [plan/README.md](plan/README.md) | The historical rebuild plan (M1–M6) |
| [status/backlog.md](status/backlog.md) | Known debts and behaviours |
| [history/](history/status-2026-11-07.md) | What was true on a given day (frozen) |
| [releases/0.1.0.md](releases/0.1.0.md) | The 0.1.0 release note |
| [media/](media/banner-2026-duo.svg) | Banner, mascot, screenshots, clips |

## Not here

Bridge, relay, wire, brain, evals and the service tools are documented in
[`services/docs/`](../services/docs/README.md) — pairing and tunnels, protocols,
knowledge format, the benchmark, the platform checklist and the split runbook.
