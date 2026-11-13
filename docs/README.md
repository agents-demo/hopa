# HOPA documentation

Two hemispheres, one rule: if a document's subject is a service, it lives in
[`services/docs/`](../services/docs/README.md) and moves with the services. If it
is about the app, the product, or both, it lives here.

```
docs/                      # app, product, and shared docs (this folder)
services/docs/             # bridge, relay, wire, brain, evals
```

## App and product

| File | Question |
|---|---|
| [guides/setup.md](guides/setup.md) | How do I build and run the app? |
| [guides/build-and-sign.md](guides/build-and-sign.md) | How is the HAP signed and installed? |
| [guides/install-phone.md](guides/install-phone.md) | How does the app reach a phone? |
| [guides/acl-request.md](guides/acl-request.md) | How is the accessibility ACL requested? |
| [product/coverage.md](product/coverage.md) | What works today, and what is blocked? |
| [product/roadmap.md](product/roadmap.md) | What comes next? |
| [product/ux.md](product/ux.md) | What is the intended experience? |

## Shared (the app and the services both read these)

| File | Question |
|---|---|
| [architecture/overview.md](architecture/overview.md) | What is HOPA made of? |
| [architecture/layers.md](architecture/layers.md) | What may import what? |
| [architecture/data-flow.md](architecture/data-flow.md) | How does one goal become an action? |
| [architecture/target-structure.md](architecture/target-structure.md) | Where is the code going, and why? |
| [contracts/](contracts/observation.md) | Observation, action and error contracts |
| [reference/bundles.md](reference/bundles.md) | Which HarmonyOS bundle belongs to which app? |
| [reference/safety.md](reference/safety.md) | What is the approval model? |
| [reference/threat-model.md](reference/threat-model.md) | What are the security limits? |
| [reference/privacy.md](reference/privacy.md) | What data is stored? |
| [reference/abuse.md](reference/abuse.md) | What is explicitly refused? |
| [reference/glossary.md](reference/glossary.md) | What do the words mean? |
| [adr/](adr/README.md) | Decisions that shaped both halves (service ADRs are linked there) |

## Decisions

- [adr/](adr/README.md) — one file per decision. ADR-0007 (taxonomy), ADR-0008
  (renames) and ADR-0011 (loop ownership) are the three that explain the current
  shape fastest.
- Four service ADRs live in
  [`services/docs/adr/`](../services/docs/adr/): 0009, 0010, 0012, 0013.

## Operations, plan, history

| Folder | Question |
|---|---|
| [operations/](operations/release.md) | How is it released, owned, versioned? |
| [plan/README.md](plan/README.md) | The historical rebuild plan (M1–M6) |
| [plan/refactor/README.md](plan/refactor/README.md) | The structural refactor and its evidence |
| [history/](history/status-2026-11-07.md) | What was true on a given day (frozen) |
| [status/backlog.md](status/backlog.md) | Known debts and behaviours |

## Service docs

Bridge, relay, wire, brain, evals and the service tools are documented in
[`services/docs/`](../services/docs/README.md): pairing and tunnels, protocols,
knowledge format, the benchmark, the platform checklist, and the split runbook.
