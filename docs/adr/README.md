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
