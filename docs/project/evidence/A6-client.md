# A6 - `AdbDevice` and the bridge client

Date: 2026-11-13. Client side of the bridge; the wire side is A5.

## What exists

- `BridgeClient`: normalises the address, sends the bearer token, per-call
  timeouts (8 s health/whoami, 45 s observe/screenshot, 20 s actions), one
  refresh attempt on 401, and `BridgeException` messages that replace the token
  with `<token>` and the base URL with `<bridge>`. It speaks the documented
  paths: `/health`, `/whoami`, `/observe`, `/foreground`, `/tap`, `/type`,
  `/swipe`, `/launch`, `/stop`, `/key`, `/screenshot`, `/apps`.
- `BridgeObservation`: the bridge's flat `nodes` become the shared
  `ObservationNode` tree with refs and bounds, and the canonical hash is
  attached.
- `AdbDevice`: `DevicePort` over the client; a ref is resolved to its bounds
  centre from the last observation, typing focuses that point first.
- Settings has a Bridge section: address, token (Keystore), `Test bridge`
  (whoami) and Save. `AppContainer.bridgedDevice()` returns the adapter when an
  address and a token exist, and `loopFor(device)` builds a loop around it; the
  chat view model picks that path per turn.

## Verified

```
cd apps/android
./gradlew :capabilities:testDebugUnitTest :app:assembleDebug   -> green
com.hopa.capabilities.bridge.BridgeClientTest: 4 tests, 0 failures
python tools/checks/check-android-structure.py                 -> 0 problems
```

The tests cover observe→tree mapping, 401→refresh with the new bearer header,
error scrubbing, and the apps parser. A live `/observe`, `/apps` and
`/screenshot` were already exercised in A5 on `emulator-5554`.

## Not done

- Pairing (code → token + refresh in one holder shared with `ChatSync`); the
  client accepts an existing token only.
- Explicit target/role selection; one bridge address is assumed.
- The 401-refreshed token is used for the rest of the process but not persisted.
- Tests for every endpoint, and a full agent turn through the bridge (A14).
