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

When a bridge is configured, it becomes the single control backend: the
accessibility path stands down even if the extension reports itself connected
(a declared-but-disabled service can leave capture pending). Failures show the
reason, e.g. `unreachable: bridge HTTP 401`. The URL stays in preferences; the
token pair lives in Asset Store and is sent nowhere except to the configured
bridge.

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
