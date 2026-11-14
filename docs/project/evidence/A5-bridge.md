# A5 - bridge `adb` transport

Date: 2026-11-13. Host: Windows; device: `emulator-5554`, API 35.

## Design

- `platform` is a first-class field: a `--devices` entry may carry
  `"platform": "android"`, and the single-device CLI takes
  `hopa-bridge --platform android --target <serial> bridge`.
- `BridgePool` builds `AndroidDevice(Adb(serial))` for Android and
  `HarmonyDevice(Device(target))` otherwise; a factory may still inject a fake.
- `/health` of a pool lists `serial`, `role` and `platform`; the single-device
  `/health` keeps its documented `{ok: true}` shape.
- Android role detection is `phone` (one process owns one handheld).
- `DevicePort` gained `screenshot(width) -> (mime, bytes)` and `apps()`.
  HarmonyOS returns JPEG from `snapshot_display` + pull; Android returns PNG
  from `exec-out screencap -p`.

## Transport and adapter

- `adb.py`: serial targeting, `devices`, `shell`, `exec_out`, `pull`, a
  testable `runner`, and `HOPA_ADB` / `ANDROID_HOME` / `LOCALAPPDATA` lookup.
- `device_android.py`: `uiautomator dump` reshaped into the shared `layout.Node`
  tree; `input tap/swipe/text/keyevent`; `resolve-activity` + `am start` with a
  `monkey -p` fallback; `am force-stop`; `dumpsys window` foreground;
  `pm list packages -3` apps; PNG screenshots.
- Non-ASCII typing is refused with a message pointing at the accessibility
  adapter, because `adb input text` is ASCII-only.

## Tests

```
cd services/bridge
python -m pytest tests -q        -> 139 passed
python -m ruff check src tests   -> All checks passed
python services/tools/checks/check-openapi.py -> ok, 22 spec paths
```

`test_adb.py` covers command construction, target parsing and failure mapping;
`test_device_android.py` parses a real uiautomator XML fixture, checks
foreground, tap/swipe/key commands, the ASCII refusal and escaping, launch with
and without a resolved component, third-party apps and PNG bytes. `test_bridge`
now also covers `/apps`.

## Hardware smoke

```
python -m hopa_bridge --platform android --target emulator-5554 bridge \
    --port 8899 --token testtoken --no-state
curl -s http://127.0.0.1:8899/health                  -> {"ok": true}
POST /observe   -> the HOPA chat tree, refs e1..e22, 1080x2400
POST /apps      -> com.hopa.android
POST /screenshot-> JSON with a PNG (129 378 bytes at that moment)
```

Direct adapter run:

```
launch com.android.settings -> foreground com.android.settings
dump_layout                -> ["Settings", "Search settings", "Network & internet", ...]
tap(Network)               -> executed
screencap -p               -> image/png, 144 590 bytes
launch com.hopa.android    -> foreground com.hopa.android
```

## Not done

- `input text` is ASCII-only; the ADBKeyboard setup screen is not built.
- The pool path (`--devices` with an Android entry) is covered by unit tests,
  not by a two-device hardware run.
- A full agent turn through the bridge is A6/A14.
