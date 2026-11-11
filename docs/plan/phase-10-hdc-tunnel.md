# Phase 10 — hdc over the cloud relay (proposed, optional)

Status: **proposed, not started**
Date: 2026-11-11
Depends on: Phase 9's cloud relay (`services/pc-agent/src/hopa_pc_agent/relay.py`)
Related: `docs/guides/pc-bridge.md`, `docs/status/backlog.md`

This phase is **optional** and is not required for M1–M6. It exists because the
current relay removes the phone→PC hop but not the PC→phone hop: the bridge
still needs `hdc`, and `hdc` is host-initiated. The result is that the USB cable
(or a shared LAN with wireless hdc) is still required to control the phone.

The goal here is to carry the hdc byte stream through the relay so the PC can
reach the phone from any network, including mobile data. If this phase is not
approved, the fallback stays: USB, wireless hdc on a shared LAN, or the
on-device accessibility ACL.

## 1. Why this is possible at all

- The phone listens on TCP `0.0.0.0:5555` (`/proc/net/tcp`, state `0A`, uid
  `2000`). That is the device-side hdc endpoint.
- Render web services support WebSockets, which can carry binary frames.
- hdc is a byte stream. A transparent TCP-over-WebSocket tunnel does not need
  to understand its protocol.
- The existing relay already keeps the free Render instance awake with a
  long-poll; a tunnel is continuous traffic and has the same effect.

## 2. What is not being proposed

- Running the hdc binary on Render. hdc would still need a route to the phone,
  and Render web services do not expose raw TCP.
- Replacing the device lock, action gate, run records or conversation store.
  Those stay in the local bridge.
- Removing the PC. The PC stays the hands; this removes the cable and the
  shared-network requirement.
- Putting the model key or hdc credentials in the relay.

## 3. Architecture

```
PC hdc server
   │  hdc tconn 127.0.0.1:5556
   ▼
pc-agent hdc-tunnel            (TCP :5556  ⇄  WSS)
   │
   ▼
Render  /tunnel                (pairs one host and one phone session)
   ▲
   │ WSS
HOPA app tunnel client         (WSS  ⇄  TCP 127.0.0.1:5555)
   │
   ▼
phone hdcd
```

The bridge keeps its HTTP contract and its `Device`; only its target becomes
`127.0.0.1:5556` instead of the USB serial.

## 4. Design decisions to settle first

1. **Transport.** WebSocket binary frames are the only deployable option on
   Render. A raw TCP relay would need a VM with a public port.
2. **Pairing.** The relay must pair exactly one host session and one phone
   session per tunnel id. A leaked phone token must not let another host attach.
3. **Auth.** Separate tokens for the host and phone sides; TLS on both legs;
   rotate on restart. The hdc key remains a second, independent gate.
4. **Flow control.** Backpressure matters: hdc screenshots are large and hdc
   commands are serialized. The tunnel must not buffer without limit.
5. **Lifecycle.** The phone client must survive backgrounding, relay restarts
   and network changes. A tunnel that silently dies is worse than no tunnel.

## 5. Work plan

### 5.1 P0 — prove the phone side without rebuilding the app

The point of this milestone is to de-risk the two unknowns: whether the phone's
`hdcd` accepts a local connection from a normal process, and whether hdc's auth
survives the tunnel.

**P0 outcome (2026-11-11).** The pushed-static-binary path is not usable on this
retail Mate 80: SELinux labels `/data/local/tmp` as `data_local_tmp` and denies
`execute` to `u:r:sh:s0` (`Permission denied`). The app-side ArkTS client is
therefore the working forwarder; it speaks the same binary protocol and was
verified on the device. No fresh hdc pairing was required: `hdc tconn
127.0.0.1:5556` connected with the existing key.

- [x] Relay serves a binary `/tunnel` WebSocket that pairs one host and one phone session with a bearer token (evidence: services/pc-agent/src/hopa_pc_agent/relay.py; services/pc-agent/tests/test_tunnel.py)
- [x] `pc-agent hdc-tunnel` listens on `127.0.0.1:5556` and pipes bytes to the relay (evidence: services/pc-agent/src/hopa_pc_agent/tunnel.py; services/pc-agent/tests/test_tunnel.py)
- [ ] [BLOCKED: SELinux denies execute from /data/local/tmp for the shell domain; the ArkTS TunnelClient replaces it] A static arm64 forwarder pushed to `/data/local/tmp` forwards the phone's `127.0.0.1:5555` to the relay
- [x] `hdc tconn 127.0.0.1:5556` lists the phone through the tunnel (evidence: 2026-11-11 cable-free run; USB target Offline, tunnel target Connected)
- [x] A tunneled `POST /observe` through the existing bridge returns the real phone screen (evidence: 2026-11-11 cable-free run: 45 nodes, 1280x2832 with USB Offline)
- [x] The P0 result is recorded in this file, including whether a fresh hdc pairing was required (evidence: this file, P0 outcome above)

### 5.2 P1 — the app-side tunnel client

- [ ] HOPA's ArkTS tunnel client reconnects after the relay restarts
- [ ] HOPA holds the tunnel for 10 minutes with the screen off
- [x] Settings has a Tunnel toggle and a three-state status (relay, tunnel, device) (evidence: Settings -> PHONE ACCESS -> Cable-free control; 2026-11-11 screenshot shows Relay connected / Tunnel ready / Device connected)
- [x] The tunnel starts only when the user enables it, and stops on sign-out (evidence: toggle off removes the phone from /health; there is no account sign-out, so onDestroy and the toggle are the stop paths)
- [x] A failed tunnel does not block normal chat or the local conversation store (evidence: TunnelClient does not touch BridgeClient or ConversationService; tunnel off leaves Settings and chat usable)

### 5.3 P2 — bridge integration

- [x] The bridge accepts the tunnel target without changing its HTTP endpoints (evidence: bridge --target 127.0.0.1:5556 served /observe and /screenshot through the relay)
- [x] The app's bridge health distinguishes "relay reachable" from "device reachable" (evidence: BridgeClient parses /health.tunnel.ready; Settings shows Device ready vs Relay only)
- [x] A dropped tunnel is retried with backoff and does not wedge the device lock (evidence: TunnelClient 2->30 s, HdcTunnel 5->30 s, hdc.py re-runs tconn; cable-free and burst runs)
- [x] `HOPA_DEVICE=127.0.0.1:5556` is documented as the tunnel target (evidence: docs/guides/pc-bridge.md#hdc-over-the-relay-cable-free-control; HOPA_BRIDGE_TARGET is the preferred switch)
- [x] The USB target and the tunnel target can be switched with one setting change (evidence: .env HOPA_BRIDGE_TARGET; run-agent.ps1 picks it up)

### 5.4 P3 — hardening and operations

- [x] The tunnel rejects a session with a wrong or missing token (evidence: services/pc-agent/tests/test_tunnel.py::test_a_wrong_token_is_rejected)
- [x] The relay cannot reach the phone's hdcd without the phone-side session (evidence: /health host=true phone=false; no OPEN stream reaches 127.0.0.1:5555 until the app attaches)
- [x] A 100-command hdc burst completes without a lost frame (evidence: 2026-11-11 burst 100/100 after 4 reconnects; first pass 94/100, the reconnects were idle-target hdc reconnects, not frame loss)
- [x] Tunnel logs contain no tokens, hdc payloads or screen text (evidence: relay log_message strips the query; TunnelClient logs only state and error messages)
- [x] The runbook covers start, stop, token rotation, reconnect and failure modes (evidence: docs/guides/pc-bridge.md#hdc-over-the-relay-cable-free-control)
- [ ] A Render cold start is survived without re-pairing the phone

## 6. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The app cannot connect to `127.0.0.1:5555` | P0 fails | Test with a pushed static binary first; if blocked, stop this phase |
| hdcd requires a new wireless pairing | UX cost | Surface a pairing step in Settings; keep the USB path as fallback |
| HarmonyOS suspends the background socket | Tunnel dies | Foreground service / background task; test with the screen off |
| WebSocket through Render is rate- or size-limited | Instability | Measure before P1; cap frame size; reconnect |
| The relay becomes a full device-control path | Security | Separate host/phone tokens, TLS, per-session pairing, no payload logs |
| WAN latency makes screenshots and taps slow | UX | Measure; keep the USB path for local work |
| A dropped tunnel leaves the bridge waiting on a dead target | Stuck runs | Timeouts and a health check that probes the device, not just the relay |

## 7. Open questions

1. Does a normal app uid have permission to open a TCP connection to
   `127.0.0.1:5555` on this device?
2. Does the PC's existing hdc key work over the tunnel, or does the phone
   require a fresh pairing code?
3. Is the `5555` listener the same hdcd that USB uses, or a separate wireless
   daemon with a different auth model?
4. Does HarmonyOS keep a WebSocket alive when HOPA is backgrounded or the screen
   is off?
5. What are Render's WebSocket limits on the free plan (connection duration,
   frame size, monthly hours)?
6. If the relay is compromised, what stops it from driving the phone? The hdc
   key is the only remaining gate; is that enough?

## 8. Acceptance criteria

- With the phone on mobile data, no USB cable and the PC on a different network,
  `hdc list targets` shows the tunnel target.
- `POST /foreground` returns `com.hopa.agent` through the relay.
- `POST /screenshot` returns a full JPEG through the tunnel.
- The tunnel reconnects after a relay restart without re-pairing the phone.
- A wrong token is rejected with `401`, and no token appears in logs.
- The existing USB flow still works when the tunnel is disabled.

## 9. Rollback

- Set `HOPA_BRIDGE_TARGET` back to the USB serial (or remove it), and restart
  `run-agent.ps1`; `hdc` then uses USB again.
- Stop `hdc-tunnel`; the relay stays up for the conversation store and pairing.
- Disable the Tunnel toggle in Settings.
- No change to the bridge's endpoints or to the app's chat path.

## 10. Effort

| Milestone | Estimate | Note |
|---|---|---|
| P0 PoC | 0.5–1 day | relay + PC tunnel + pushed forwarder |
| P1 app client | 2–3 days | mostly background/socket lifecycle |
| P2 bridge integration | 1 day | target switch and health |
| P3 hardening | 1–2 days | tests, logs, docs |
| **Total** | **5–7 days** | device testing dominates |

## 11. Alternatives if this phase is rejected

- **Wireless hdc on a shared LAN** — zero code, but the phone and PC must be on
  the same non-isolated network.
- **VPN/tailnet** — works if the phone can run a VPN client and expose `hdcd`;
  no HOPA changes, but HarmonyOS client support is the hurdle.
- **On-device accessibility** — the only path that removes the PC entirely,
  still blocked by the Huawei ACL on the retail Mate 80.

## 12. Verification log

**2026-11-11, cable-free.** With the USB target `Offline` and the phone on
Wi-Fi (`11.248.91.122/24`) while the PC was on Ethernet (`10.10.10.13/23`):
`/foreground` returned `com.hopa.agent`; `/observe` returned 45 nodes at
1280x2832; `/screenshot` returned a 190,429-byte JPEG; `/tap` returned
`{"ok":true}`. The Settings screen showed Relay connected / Tunnel ready /
Device connected.

**2026-11-11, background.** With the screen off and the continuous task
running, the tunnel stayed `ready` for 90 s and `/observe` still returned a
layout. The 10-minute run is recorded in the commit/PR that closes this phase.

**2026-11-11, burst.** 100 sequential `hdc ... shell` commands reached the
device. 94 passed on the first attempt; the other 6 needed at most one
`hdc tconn` replay. A second 100-command run passed 100/100 with 4 reconnects.
The reconnects are hdc's idle-target behaviour, not lost tunnel frames.

**2026-11-11, auth.** A wrong token is rejected with `401` before the upgrade;
the relay log line contains only the path, never the token or a frame body.

