# Architecture decision records

One file per decision. An ADR is immutable once accepted; a later ADR may
supersede it. Format:

```
# ADR-NNNN — Title

- Status: proposed | accepted | superseded by ADR-NNNN
- Date: YYYY-MM-DD
- Owners: names

## Context
## Decision
## Consequences
## Alternatives considered
```

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-brain-hosting.md) | Brain hosting: JVM service first, ArkTS later | accepted |
| [0002](0002-knowledge-format.md) | Knowledge format and bundle mapping | accepted |
| [0003](0003-sandbox-runtime.md) | Sandbox: Pyodide + QuickJS, no Linux | accepted |
| [0004](0004-acl-strategy.md) | ACL strategy and foreground fallback | accepted |
| [0005](0005-pc-tethered-vs-standalone.md) | PC-tethered vs standalone product split | accepted |
| [0006](0006-model-provider-and-budget.md) | Model provider, transport and budget | accepted |
| [0007](0007-top-level-taxonomy.md) | Top-level taxonomy and what "agent" means | superseded in part by 0013 |
| [0008](0008-python-distribution-renames.md) | Python distribution renames and CLI aliases | accepted |
| [0009](../../../services/docs/adr/0009-relay-is-a-server-half.md) | The relay is a server half; the PC keeps its tunnel client | accepted |
| [0010](../../../services/docs/adr/0010-shared-code-lives-in-packages.md) | Shared code lives in `packages/`, not in a service | superseded by 0012 |
| [0011](0011-loop-ownership.md) | Where the loop runs, and what a backend owns | accepted, superseded in part by 0016 |
| [0012](../../../services/docs/adr/0012-shared-service-code-lives-under-services.md) | Shared service code lives under `services/` | accepted |
| [0013](../../../services/docs/adr/0013-service-related-code-lives-under-services.md) | Everything service-related lives under `services/` | accepted |
| [0014](0014-retire-the-rebuild-plan.md) | Retire the M1-M6 rebuild plan from the working tree | accepted |
| [0015](0015-docs-by-audience.md) | Documentation is five folders, by audience | accepted |
| [0016](0016-clients-own-the-loop.md) | Each client owns its agent loop | accepted |
| [0017](0017-android-dual-execution.md) | Android acts through the bridge and on-device | accepted |
| [0018](0018-shared-data-per-client-code.md) | Share the data and the fixtures, not the loop | accepted |
| [0019](0019-offline-and-model-network.md) | The model needs a network; the shell does not | accepted |
| [0020](0020-android-is-the-active-client.md) | Android is the active client; Windows is next; Harmony is frozen | accepted |

Create the next ADR by copying the template below.

```markdown
# ADR-NNNN — Title

- Status: proposed
- Date: YYYY-MM-DD
- Owners:

## Context

## Decision

## Consequences

## Alternatives considered
```
