# HOPA services documentation

This folder documents everything that lives under `services/`: the device plane,
the cloud relay, the shared wire package, the brain, the evaluation suite and the
service tools. All of it moves together when the services get their own repository
(ADR-0013), which is why these documents sit here rather than in `docs/`.

App and product documentation is in [`docs/`](../../docs/README.md) and is not
repeated here.

## What runs here

| Folder | Role | Docs |
|---|---|---|
| [`services/bridge`](../bridge/README.md) | Device plane: drives a phone/2-in-1 over hdc through `DevicePort` | [pc-bridge](guides/pc-bridge.md), [device-testing](guides/device-testing.md) |
| [`services/relay`](../relay/README.md) | Cloud half: forwards a remote phone to a linked PC | [pc-bridge](guides/pc-bridge.md) |
| [`services/wire`](../wire/README.md) | WebSocket + tunnel framing shared by bridge and relay | [protocols](reference/protocols.md) |
| [`services/brain`](../brain/README.md) | Kotlin knowledge router | [brain](reference/brain.md), [knowledge](reference/knowledge.md), [skills](reference/skills.md) |
| `services/backend` | Reserved for the server loop (ADR-0011); no package yet | — |
| [`services/evals`](../evals) | `bench` (tasks, scoring) and `baseline` (reference driver) | [bench](product/bench.md), [results](product/bench-results-v0.md) |
| [`services/tools`](../tools) | Scripts and checks that drive the services | — |

## Guides

| File | Question |
|---|---|
| [pc-bridge.md](guides/pc-bridge.md) | How do I run the bridge, pair a device, use the relay and the tunnel? |
| [adding-a-platform.md](guides/adding-a-platform.md) | How do I add Android or Windows as a `DevicePort` adapter? |
| [device-testing.md](guides/device-testing.md) | How do I drive a device through the bridge? |

## Reference

| File | Question |
|---|---|
| [protocols.md](reference/protocols.md) | Which HTTP, WebSocket and MCP endpoints exist? |
| [brain.md](reference/brain.md) | What is the brain service? |
| [knowledge.md](reference/knowledge.md) | How is app/site knowledge written? |
| [skills.md](reference/skills.md) | How are skills written? |

## Benchmark

| File | Question |
|---|---|
| [bench.md](product/bench.md) | How is HOPA-Bench defined and scored? |
| [bench-results-v0.md](product/bench-results-v0.md) | What did the first run show? |

## Operations

| File | Question |
|---|---|
| [repo-split.md](operations/repo-split.md) | What moves to the services repository, and in what order? |

## Decisions

| ADR | Decision |
|---|---|
| [0009](adr/0009-relay-is-a-server-half.md) | The relay is the server half; the PC keeps its tunnel client |
| [0010](adr/0010-shared-code-lives-in-packages.md) | Shared code, first location (superseded by 0012) |
| [0012](adr/0012-shared-service-code-lives-under-services.md) | Shared service code lives under `services/` |
| [0013](adr/0013-service-related-code-lives-under-services.md) | Everything service-related lives under `services/` |

The central index in [`docs/design/decisions/`](../../docs/design/decisions/README.md) links back here.

## Contracts and policy are shared

The wire formats and the safety/privacy rules bind both the app and the services,
so they stay in `docs/` and are not duplicated: see
[`contracts/`](../../docs/reference/contracts/observation.md),
[`reference/safety.md`](../../docs/reference/safety.md) and
[`reference/threat-model.md`](../../docs/reference/threat-model.md). The machine
contracts are in [`contracts/openapi/`](../../contracts/openapi/README.md).
