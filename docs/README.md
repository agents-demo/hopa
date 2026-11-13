# HOPA documentation

Five folders by what you are looking for:

```
docs/
├─ design/     what it is and why (architecture, decisions, product)
├─ guides/     how to do it (per platform; harmony today, android/windows later)
├─ reference/  what a thing is called (contracts, bundles, glossary, policy)
├─ project/    how we run it (plan, status, operations, releases, archive)
└─ media/      pictures and clips
```

Service documentation lives with the services: [`services/docs/`](../services/docs/README.md).

## Design

| File | Question |
|---|---|
| [architecture/overview.md](design/architecture/overview.md) | What is HOPA made of? |
| [architecture/layers.md](design/architecture/layers.md) | What may import what? |
| [architecture/data-flow.md](design/architecture/data-flow.md) | How does one goal become an action? |
| [architecture/target-structure.md](design/architecture/target-structure.md) | The historical audit that produced the current folders |
| [decisions/](design/decisions/README.md) | Why was a decision made? One ADR per decision |
| [product/roadmap.md](design/product/roadmap.md) | What comes next? |
| [product/coverage.md](design/product/coverage.md) | What works today, and what is blocked? |
| [product/ux.md](design/product/ux.md) | What is the intended experience? |

## Guides

| File | Question |
|---|---|
| [harmony/setup.md](guides/harmony/setup.md) | How do I build and run the HarmonyOS app? |
| [harmony/build-and-sign.md](guides/harmony/build-and-sign.md) | How is the HAP signed and installed? |
| [harmony/install-phone.md](guides/harmony/install-phone.md) | How does the app reach a phone? |
| [harmony/acl-request.md](guides/harmony/acl-request.md) | How is the accessibility ACL requested? |

`guides/android/` and `guides/windows/` appear when those apps do.

## Reference

| File | Question |
|---|---|
| [contracts/](reference/contracts/observation.md) | Observation, action and error contracts |
| [bundles.md](reference/bundles.md) | Which HarmonyOS bundle is which app? |
| [glossary.md](reference/glossary.md) | What do the words mean? |
| [safety.md](reference/safety.md) | What is the approval model? |
| [threat-model.md](reference/threat-model.md) | What are the security limits? |
| [privacy.md](reference/privacy.md) | What data is stored? |
| [abuse.md](reference/abuse.md) | What is explicitly refused? |

## Project

| File | Question |
|---|---|
| [plan/README.md](project/plan/README.md) | The active plan, with evidence |
| [status.md](project/status.md) | Where the daily experience stands, and known debts |
| [operations/release.md](project/operations/release.md) | How is a release cut? |
| [operations/versioning.md](project/operations/versioning.md) | How are versions numbered? |
| [operations/owners.md](project/operations/owners.md) | Who owns what? |
| [operations/sbom.json](project/operations/sbom.json) | What ships in the HAP? |
| [releases/0.1.0.md](project/releases/0.1.0.md) | The 0.1.0 release note |
| [archive/README.md](project/archive/README.md) | Dated evidence: measurements, platform limits, provenance |

## Media

[media/](media/banner-2026-duo.svg) - banner, mascot, screenshots, clips.
