# Service docs

Everything here moves with `services/` when it becomes its own repository
(ADR-0013). The app and shared docs are in [`docs/`](../../docs/README.md).

## Guides

| File | Question |
|---|---|
| [pc-bridge.md](guides/pc-bridge.md) | How do I run the bridge, relay and tunnel? |
| [adding-a-platform.md](guides/adding-a-platform.md) | How do I add Android or Windows? |
| [device-testing.md](guides/device-testing.md) | How do I drive a device through the bridge? |

## Reference

| File | Question |
|---|---|
| [protocols.md](reference/protocols.md) | Which HTTP, WebSocket and MCP endpoints exist? |
| [brain.md](reference/brain.md) | What is the brain service? |
| [knowledge.md](reference/knowledge.md) | How is app/site knowledge written? |
| [skills.md](reference/skills.md) | How are skills written? |

## Product

| File | Question |
|---|---|
| [bench.md](product/bench.md) | How is HOPA-Bench defined? |
| [bench-results-v0.md](product/bench-results-v0.md) | What did the first bench run show? |

## Operations

| File | Question |
|---|---|
| [repo-split.md](operations/repo-split.md) | What moves to the services repository, and in what order? |

## Decisions

| ADR | Decision |
|---|---|
| [0009](adr/0009-relay-is-a-server-half.md) | The relay is the server half; the PC keeps its tunnel |
| [0010](adr/0010-shared-code-lives-in-packages.md) | Shared code, first location (superseded by 0012) |
| [0012](adr/0012-shared-service-code-lives-under-services.md) | Shared service code lives under `services/` |
| [0013](adr/0013-service-related-code-lives-under-services.md) | Everything service-related lives under `services/` |

## Shared, stays in `docs/`

The architecture map, the contracts, safety/privacy/threat model, the glossary and
the bundle catalogue describe both halves and are not duplicated here. Links point
back to `docs/`.
