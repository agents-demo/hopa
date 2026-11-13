# Adding a platform

The bridge drives a device through one seam, `DevicePort`. HarmonyOS is the first
implementation; Android and Windows are adapters, not forks.

## The port

`services/bridge/src/hopa_bridge/device_port.py` (introduced in R6 of
`docs/plan/README.md`) declares:

| Method | Answers |
|---|---|
| `observe()` | what is on screen, as text nodes with bounds |
| `tap(x, y)` | one pointer press |
| `type(text, x?, y?)` | type, optionally after focusing a point |
| `swipe(from_x, from_y, to_x, to_y, velocity)` | a drag |
| `screenshot(width)` | a JPEG, optionally scaled |
| `launch(bundle, ability)` | start an app, then report what came forward |
| `foreground()` | which app owns the screen |
| `apps()` | installed apps as `{bundle, label}` |
| `serial`, `platform` | identity for the registry |

Rules that keep the seam honest:

1. The port never decides whether an action is allowed; the gate does.
2. The port never holds a token or a model key.
3. A sparse platform says so: an empty tree is `observe()` returning few nodes,
   not an invented node.
4. `device_port.py` is the only file the API layer may call; `transport/` is the
   only place raw process/IO calls live.

## Checklist for a new platform

- [ ] Add `device_<platform>.py` implementing `DevicePort`.
- [ ] Register `platform` in the device registry (`devices.json` keeps working
      without it; the default is `harmony`).
- [ ] Handler tests run against the fake adapter, not a device.
- [ ] One hardware proof: `devices`, `observe`, `screenshot`, and one tap, with
      the serial and the date recorded in the PR.
- [ ] Update `contracts/openapi/bridge.v1.yaml` only if the wire shape changed.
- [ ] Add the platform to `docs/reference/protocols.md` if it introduces a new
      transport.

## Where the client lives

The app that *uses* the platform is separate: `apps/android` and `apps/windows`
each own a shell and a client for `contracts/`, and neither may import
`services/` internals. See their READMEs.
