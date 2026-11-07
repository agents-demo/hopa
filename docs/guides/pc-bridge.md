# PC-tethered control bridge

Status: **wired into the app and verified end to end on the Pura 90 emulator.**

This is the M4 fallback: when the on-device accessibility service cannot be
enabled, the phone app drives other apps through this server on the PC, which
uses `hdc` + `uitest`. It is the same control path as `pc-agent`, behind a
token-authenticated HTTP API.

## Run

```bash
pc-agent bridge --port 8765
# prints:
# bridge listening on http://127.0.0.1:8765
# token: <generated>
```

Set `HOPA_BRIDGE_TOKEN` to choose the token instead of generating one.

### Reaching the PC from the phone

- **Emulator (QEMU user-mode NAT):** use `http://10.0.2.2:8765`. Bind the
  server to `0.0.0.0` (`--host 0.0.0.0`) so the guest's traffic is accepted.
- **Physical phone on the same Wi-Fi:** bind `0.0.0.0` and use the PC's LAN
  address, e.g. `http://192.168.1.10:8765`. Allow the port in the host firewall.
- **USB only (`hdc`):** `hdc rport tcp:8765 tcp:8765` works, but the reverse
  tunnel is reset whenever the `hdc` server restarts, which shows up as an
  aborted request. Re-create the rule after `hdc start`.

## App setup

Settings tab -> **PC bridge (fallback control)**:

1. `http://10.0.2.2:8765` (or the LAN address).
2. The bridge token.
3. **Connect**; the status must read `connected`.

When a bridge is configured, it becomes the single control backend: the
accessibility path stands down even if the extension reports itself connected
(a declared-but-disabled service can leave capture pending). Failures show the
reason, e.g. `unreachable: bridge HTTP 401`. The URL and token are saved in the
app preferences so the connection survives a restart; they are not sent
anywhere except to the configured bridge.

## Security

- Every `POST` requires `Authorization: Bearer <token>`; comparison is
  constant-time.
- Default bind is `127.0.0.1`. There is **no TLS**; do not expose the port to an
  untrusted network.
- The bridge can tap and type anything the device shows. Treat the token like a
  password.
- `/health` is unauthenticated and reveals only that the server is alive.

## Protocol

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/health` | — | `{"ok":true}` |
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
