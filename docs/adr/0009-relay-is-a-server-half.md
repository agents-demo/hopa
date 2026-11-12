# ADR-0009 — The relay is a server half; the PC keeps its tunnel client

- Status: accepted
- Date: 2026-11-12

## Context

`services/pc-agent` currently bundles two roles in one package:

- the **bridge**: observe/act on a device over `hdc` + `uitest`, the chat store,
  images, pairing and tokens;
- the **relay**: a public web service that forwards authenticated phone requests
  to a PC that dialled out to it (`render.yaml` deploys it).

`relay.py` holds the server (`Relay`, the serve loop) and `tunnel.py` holds *both*
the relay-side `TunnelRegistry` and the PC-side `HdcTunnel`/`serve_hdc_tunnel`.
`cli.py` also exposes `cloud-link` and `hdc-tunnel`, which are **PC** commands used
by `tools/scripts/run-agent.ps1`.

The naive split — move `relay.py`, `tunnel.py`, `ws.py` into `services/relay` —
would force `hopa-relay` onto every PC and break `hdc-tunnel`.

## Decision

- `services/relay` owns the **server half only**: the `Relay` implementation, its
  serve loop, the `TunnelRegistry`, and the WebSocket frame codec shared by both
  ends. It depends on nothing from the bridge.
- `services/bridge` keeps the **PC half**: `cloud_link` (dial out) and
  `tunnel_pc` (serve the local hdc port), renamed from `tunnel.py` without
  behaviour change.
- Each package has its own CLI root; there is no shared `common/` module. If a
  helper is genuinely shared it is a few lines and is duplicated, or it moves to
  `contracts/` as a format, not code.
- `render.yaml` installs and starts only `services/relay`.
- For one release, `hopa-bridge relay` prints "moved to hopa-relay" and exits 2,
  so an old script fails loudly instead of silently doing nothing.

## Consequences

- A PC never installs cloud code; a relay host never installs `hdc`.
- Two deployables, two test suites, two failure modes — which is the point.
- The split is one commit for the packages and one for `render.yaml`, so a Render
  preview can be verified before the default branch deploys.

## Alternatives considered

- **Keep one package and split later.** Rejected: the separate repository is the
  stated direction, and the split is cheaper now than after a backend lands.
- **Move the whole tunnel module to the relay and make PCs depend on the relay
  package.** Rejected: it inverts the dependency and breaks the PC tunnel.
- **Duplicate the frame codec instead of sharing a package.** Rejected: the codec
  is the wire contract; two copies would drift.
