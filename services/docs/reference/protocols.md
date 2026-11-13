# Protocols

One index of every wire format HOPA speaks. Code is authoritative; this page says
where to look and what must not drift.

| Protocol | Who talks | Transport | Contract |
|---|---|---|---|
| **Bridge HTTP** | `@hopa/app` (`BridgeClient`, `ChatSync`) → `services/bridge` | HTTP + JSON on `127.0.0.1:8766` (reverse port) or the relay | [`contracts/openapi/bridge.v1.yaml`](../../../contracts/openapi/bridge.v1.yaml) |
| **Relay** | phone → relay → PC | WebSocket, bearer token | `services/relay` (server half), `services/bridge/cloud_link.py` (PC half), `services/wire`; guide: [pc-bridge](../guides/pc-bridge.md) |
| **Brain HTTP** | bridge / baseline → `services/brain` | HTTP + JSON | [brain](brain.md) |
| **MCP** | any MCP client → `hopa-bridge mcp` | stdio, JSON-RPC | `services/bridge/mcp_server.py` |
| **Action / observation / decision / run-record** | app, baseline, bench | JSON in memory and in logs | [`contracts/schemas/`](../../../../../docs/reference/contracts/schemas) and [contracts](../../../docs/reference/contracts/action.md) |

## Bridge HTTP rules

- **Auth.** Every path except `/pair` and `/refresh` requires
  `Authorization: Bearer <token>`. The bootstrap token never expires; a paired
  token expires after twelve hours, and every pair or refresh rotates both.
- **Routing.** A single-device bridge ignores routing headers. A pool chooses the
  device by `X-Hopa-Role` (`phone`, `2in1`), by `X-Hopa-Read` for cross-reads, or
  by the `/d/{serial}/...` path prefix. `POST /pair` is routed by role; without
  one it goes to the phone entry.
- **Errors.** Non-2xx responses carry `{"error": "..."}`; clients show the message
  after stripping transport detail.
- **Change rule.** A path, method or payload change edits
  `contracts/openapi/bridge.v1.yaml` in the same pull request.
  `services/tools/checks/check-openapi.py` fails when the spec and the handlers disagree,
  in both directions.

## Why there is no `/v1` prefix yet

The bridge is deployed to PC desktops and to one relay, and both move with the
repository, so a breaking change can update every caller in one commit. The
prefix becomes worthwhile when an Android or Windows client ships on its own
schedule; the decision is recorded in `docs/project/plan/README.md`.

## Related

- [pc-bridge guide](../guides/pc-bridge.md) — how to run it, pair a device, tunnel.
- [skills](skills.md), [privacy](../../../docs/reference/privacy.md), [safety](../../../docs/reference/safety.md) — what the device
  data may contain and what the gate does with it.
