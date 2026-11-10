# PC-tethered control bridge

Status: **wired into the app and verified end to end on the Pura 90 emulator.**

This is the M4 fallback: when the on-device accessibility service cannot be
enabled, the phone app drives other apps through this server on the PC, which
uses `hdc` + `uitest`. It is the same control path as `pc-agent`, behind a
token-authenticated HTTP API.

## Run

```bash
pc-agent bridge --port 8765 --pair-code 246810
# prints:
# bridge listening on http://127.0.0.1:8765
# token: <generated>
# pair code: 246810
# token ttl: 12 h
```

Set `HOPA_BRIDGE_TOKEN` to choose the bootstrap token instead of generating one,
and `HOPA_PAIR_CODE` to fix the six-digit code. `--token-ttl-hours` (or
`HOPA_TOKEN_TTL_HOURS`) sets how long an access token lives; 12 hours is the
default.

## Tokens

- `/pair` with the six-digit code returns an access token, a refresh token and
  `expires_in`. Both are rotated on every pair and every refresh, so a leaked
  token stops working at the next rotation.
- The app keeps the pair in HarmonyOS Asset Store, not in preferences, and
  refreshes on its own when a request comes back `401` with `token expired`.
- `pair` and `refresh` are limited to five attempts a minute each; the six-digit
  code is therefore not guessable in practice.
- Restarting the bridge issues a new refresh token; the phone then needs to pair
  again from **Settings -> Bridge setup**.

### Reaching the PC from the phone

- **Emulator (QEMU user-mode NAT):** use `http://10.0.2.2:8765`. Bind the
  server to `0.0.0.0` (`--host 0.0.0.0`) so the guest's traffic is accepted.
- **Physical phone on the same Wi-Fi:** bind `0.0.0.0` and use the PC's LAN
  address, e.g. `http://192.168.1.10:8765`. Allow the port in the host firewall.
- **USB only (`hdc`):** `hdc rport tcp:8765 tcp:8765` works, but the reverse
  tunnel is reset whenever the `hdc` server restarts, which shows up as an
  aborted request. Re-create the rule after `hdc start`.

## App setup

Settings -> **Bridge setup** (guided, three steps):

1. Connect the phone by USB and confirm the PC sees it: `hdc list targets`.
2. The address the bridge listens on (`http://127.0.0.1:8766` with a reverse
   port) and the six-digit code the bridge printed.
3. **Pair**; the status must read **Connected**.

The older inline URL + token fields still work for a bootstrap token, but the
wizard is the path that stores a rotating pair.

## One process, several devices

`BridgePool` puts one listener in front of one `BridgeServer` per device, so a
single process serves the phone and the 2-in-1:

```bash
pc-agent bridge --port 8766 --devices devices.json
```

The file is a list; one entry per device:

```json
[{"serial": "2SX...", "token": "hopaphone", "pair": "246810", "role": "phone",
  "sessions_key": "hopareadonly-phone", "state": "C:/Users/me/.hopa/bridge-8766-2SX....json"},
 {"serial": "3QC...", "token": "hopalaptop", "pair": "135790", "role": "2in1"}]
```

Each request says which device it means, in this order:

1. `/d/<serial>/...` — explicit, always wins;
2. `X-Hopa-Role: phone` or `X-Hopa-Role: 2in1` — what both apps send now;
3. `/sessions` without a role — the phone, because the snapshot is a phone idea;
4. a pool with exactly one device — no header needed (legacy clients);
5. otherwise `400`, because guessing which device to tap is not acceptable.

Tokens stay per device, so the phone's token cannot act on the laptop. The pool
forwards the request untouched; authentication, rate limits and the device lock
all stay in the device server that owns them.

**Sessions travel both ways, read-only.** Each shell pushes its own snapshot
when it changes (`POST /sessions` with its role and its own token). To read the
other side, a shell sends `X-Hopa-Read: phone` or `X-Hopa-Read: 2in1` on
`GET /sessions`; the pool accepts any live credential it knows, so the phone
never needs the laptop's secret. The laptop shows one merged, newest-first list
with a small body mark for origin; the phone shows a “From your laptop” group
inside Chats that opens a read-only thread. Nothing writes across, and there is
no merge: the other copy stays owned by the machine it lives on.

**Continue here** is the escape hatch: it copies the other side's thread into a
local conversation (marked with the local body) and leaves the original alone.
Both directions have it — the laptop's read-only viewer and the phone's
read-only thread header — so you can pick up a thread anywhere without the two
copies ever fighting.

`hdc` allows only one device to own a given *device-side* port, so the two
shells cannot both listen on 8766 locally. Current mapping:

| Device | Tunnel | App address |
|---|---|---|
| phone | `hdc -t <phone> rport tcp:8768 tcp:8766` | `http://127.0.0.1:8768` |
| 2in1 | `hdc -t <2in1> rport tcp:8766 tcp:8766` | `http://127.0.0.1:8766` |

`tools\scripts\bridges.ps1` writes the device file from `hdc list targets`,
starts or stops the one process, and adds the tunnels. `deploy.ps1` calls it.

## The 2in1 as a second device

A HarmonyOS laptop (`const.product.devicetype` = `2in1`) is an `hdc` device
like the phone, so it gets the same treatment — with one difference: a bridge
process serves **one** device, so the laptop needs its own instance and port.

```bash
py -3 -m hopa_pc_agent --target 3QC0225821000268 bridge \
    --port 8767 --token hopalaptop --pair-code 135790
hdc -t 3QC0225821000268 rport tcp:8767 tcp:8767
```

`tools\scripts\bridges.ps1` does both devices at once (start, `-Status`,
`-Stop`), and `deploy.ps1` calls it, so a bridge that died does not silently
turn into "PC bridge offline" after an install.

Then in the laptop app: **Settings -> PC BRIDGE**, address
`http://127.0.0.1:8767`, the key the bridge printed, **Connect**. The status
reads `Connected.` only after a real `/health` answer; otherwise it shows the
transport error.

Scripted first runs can inject the pair instead:

```bash
aa start -a LaptopAbility -b com.hopa.agent \
  --ps hopa.bridge_url http://127.0.0.1:8767 \
  --ps hopa.bridge_key hopalaptop
```

What this buys on the laptop, all through the same endpoints:

- `/observe` and `/screenshot` — the agent reads what is on the screen;
- `/tap`, `/type`, `/swipe`, `/key` — it acts, still behind the approval gate;
- `/launch` and `/foreground` — it opens an app and confirms it is in front,
  and uses the same call to bring HOPA back afterwards.

`deploy.ps1` restores `tcp:8766` for the phone and `tcp:8767` for the 2in1,
because `hdc install` drops reverse ports.

Limits, stated honestly: no PC, no bridge. The bridge is a foreground process
on the PC; when it stops, the laptop says "connect the PC bridge" instead of
pretending it can see. The bridge token is still a static key on this path —
the rotating pair is the phone wizard.

When a bridge is configured, it becomes the single control backend: the
accessibility path stands down even if the extension reports itself connected
(a declared-but-disabled service can leave capture pending). Failures show the
reason, e.g. `unreachable: bridge HTTP 401`. The URL stays in preferences; the
token pair lives in Asset Store and is sent nowhere except to the configured
bridge.

### The pair survives a restart

The bridge keeps `~/.hopa/bridge-<port>.json` (mode 0600) with the access
token, the refresh token, its issue time, the read-only sessions key and the
last conversation snapshot. On
startup it adopts that pair only when it is still inside the TTL and was
issued for the same base token; otherwise the file is replaced and clients
pair again. This is why `Ctrl+C` on the PC no longer looks like a lost phone.

Keeping the snapshot matters for the other shell: without it a restart leaves
the laptop's "From your phone" list empty until the phone happens to change a
conversation. The phone also pushes once at boot now.

Override the path with `--state <file>`, or disable it with `--no-state` so
every restart requires a fresh pair. A port of `0` (tests) never writes state.
`--sessions-key <value>` pins the read-only key; the dev script uses
`hopareadonly-8766` / `hopareadonly-8767` so both shells can be configured by
copy-paste without a leading dash (which `aa start --ps` eats).

## Security

- Every `POST` requires `Authorization: Bearer <token>`; comparison is
  constant-time. `/pair` and `/refresh` are the only unauthenticated writes and
  are rate-limited.
- Access tokens expire (12 h by default) and both tokens rotate on every pair or
  refresh.
- Default bind is `127.0.0.1`. There is **no TLS**; do not expose the port to an
  untrusted network.
- The bridge can tap and type anything the device shows. Treat the tokens like
  passwords.
- `/health` is unauthenticated and reveals only that the server is alive.

## Protocol

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/health` | — | `{"ok":true}` |
| POST | `/pair` | `{"code":"123456"}` | `{"token","refresh","expires_in"}` |
| POST | `/refresh` | `{"refresh":"<token>"}` | `{"token","refresh","expires_in"}` |
| GET | `/sessions` | — | `{"sessions":[…],"updated":unix}` |
| POST | `/sessions` | `{"sessions":[…]}` | `{"ok":true,"count":n}` |
| POST | `/observe` | `{}` | `{"text","nodes":[{"ref","text","description","type","bounds","clickable"}],"width","height"}` |
| POST | `/foreground` | `{}` | `{"bundle"}` (the bundle in front, or `""`) |
| POST | `/screenshot` | `{}` | `{"mime":"image/jpeg","bytes":int,"image":"<base64>"}` |
| POST | `/tap` | `{"x","y"}` | `{"ok":true}` |
| POST | `/type` | `{"text","x"?,"y"?}` | `{"ok":true}` |
| POST | `/launch` | `{"bundle","ability"?}` | `{"ok":true,"foreground":"<bundle>|''"}` |
| POST | `/key` | `{"name"}` | `{"ok":true}` |
| POST | `/swipe` | `{"from_x","from_y","to_x","to_y","velocity"?}` | `{"ok":true}` |

`/launch` waits up to 6 s for the bundle to reach the foreground and reports it
in `foreground`; an empty value means "the command was accepted but the app was
not confirmed in front", which is not treated as a failure.

`ref` values are stable only for one `/observe` response; the client resolves a
ref to bounds from that response before tapping. The app shows the element list
to the model (`e1 Button "Web"`), and the model must target a `ref`.

## Verified on the emulator (2026-11-07)

1. Connect from Settings: `connected` over `http://10.0.2.2:8765`.
2. Ask "Tap the Web tab.": the bridge logged `POST /observe`, then `POST /tap`;
   the app switched from Chat to the Web tab and the loop re-observed (795
   chars, 34 nodes) before finishing with one executed action.
3. `POST /screenshot` returns a JPEG of the device (1.2 s); the **More ->
   Screens** page renders it as a data URI. A payment prompt appears only
   because HOPA's own greeting contains the word "payment"; allowing it runs
   the tap. Payment screens are still fail-closed.
4. `run: start` -> continuous task started -> work -> `background: continuous
   task stopped` in hilog, so a run can outlive the switch to another app.

On 2026-11-08 the full chain ran in one request with the fixed loop:
`Open Settings and tap Network and internet.` logged `route: Settings score=8`,
`run: done outcomes=2`, `ui.launch` (bridge) ok, then `ui.tap e8` ok. The
post-tap observation was the Settings WLAN page (25 nodes, `VirtWifi`,
`Available`). The bridge log showed `/launch`, `/observe`, `/tap`, `/observe`,
so launch -> observe -> tap -> observe is verified on the emulator.

## Sessions relay (H3)

The bridge keeps one **snapshot** of the phone's conversations so a laptop can
read them without the phone opening a port:

- the phone `POST`s its sessions when they change (debounced);
- the laptop `GET`s them and shows a read-only "From your phone" list;
- the snapshot is capped at 512 KB and requires the same bearer token;
- there is no merge logic: two-way sync would need conflict rules and is not
  part of v1.

## Tests

```bash
pytest pc-agent          # includes test_bridge.py
```

The tests run a real HTTP server on an ephemeral port with a fake device.

## Limits

- Requires the PC, `hdc` and an unlocked device.
- One device per bridge process.
- The model receives text and bounds, not the screenshot; the **Screens** page
  shows the JPEG for a human.
- `/observe` retries once on a transport error, both in the app and on the PC.
- No wake/unlock; a locked screen fails the action.
- `hdc` is flaky under load: `/observe` normally takes 1.5-2.3 s, but an `hdc`
  stall can take longer. The app's read timeout is 45 s.
