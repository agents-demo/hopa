# PC-tethered control bridge

Status: **server implemented and tested; app client not wired yet.**

This is the M4 fallback: when the on-device accessibility service cannot be
enabled, the phone app can drive other apps through this server on the PC, which
uses `hdc` + `uitest`. It is the same control path as `pc-agent`, behind a
token-authenticated HTTP API.

## Run

```bash
pc-agent bridge --port 8765
# prints:
# bridge listening on http://127.0.0.1:8765
# token: <generated>
```

Set `HOPA_BRIDGE_TOKEN` to choose the token instead of generating one. Bind to
`0.0.0.0` only when the phone must reach the PC over the LAN:

```bash
pc-agent bridge --host 0.0.0.0 --port 8765
```

## Security

- Every `POST` requires `Authorization: Bearer <token>`; comparison is
  constant-time.
- Default bind is `127.0.0.1`. There is **no TLS**; do not expose the port to an
  untrusted network.
- The bridge can tap and type anything the device shows. Treat the token like a
  password.
- `/health` is unauthenticated and reveals only whether a device is connected.

## Protocol

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/health` | — | `{"ok":true,"device":true}` |
| POST | `/observe` | `{}` | `{"text","nodes":[{"ref","text","description","type","bounds","clickable"}],"width","height"}` |
| POST | `/tap` | `{"x","y"}` | `{"ok":true}` |
| POST | `/type` | `{"text","x"?,"y"?}` | `{"ok":true}` |
| POST | `/launch` | `{"bundle","ability"?}` | `{"ok":true}` |
| POST | `/key` | `{"name"}` | `{"ok":true}` |
| POST | `/swipe` | `{"from_x","from_y","to_x","to_y","velocity"?}` | `{"ok":true}` |

`ref` values are stable only for one `/observe` response; the client must
resolve a ref to bounds from that response before tapping.

## Tests

```bash
pytest pc-agent          # includes test_bridge.py
```

The tests run a real HTTP server on an ephemeral port with a fake device.

## Limits

- Requires the PC, `hdc` and an unlocked device.
- One device per bridge process.
- No screenshot endpoint yet; the client uses text and bounds.
- No wake/unlock; a locked screen fails the action.

## Next

Wire `RemoteScreenSource` and `RemoteUiCapability` in the app, then use the same
capability interface as the accessibility path.
