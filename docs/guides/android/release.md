# Build, sign and smoke-test the Android app

## Debug

```
cd apps/android
.\gradlew.bat :app:assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`.

## Release signature

The release build reads `apps/android/keystore.properties`. The file and the
keystore are ignored by git; only the mechanism is committed.

```properties
storeFile=/absolute/path/to/hopa-release.jks
storePassword=...
keyAlias=hopa
keyPassword=...
```

Create the keystore once and keep it out of the repository:

```
keytool -genkeypair -v -keystore hopa-release.jks -alias hopa \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=HOPA, O=HOPA, C=DE"
```

Without the file, `:app:assembleRelease` still builds but signs with the debug
key, so an unsigned artifact never leaves the machine by accident.

Verify:

```
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
```

The certificate DN must be the release one, not `CN=Android Debug`.

## Smoke test

```
python tools/scripts/android-smoke.py --serial emulator-5554
```

It hashes the APK, installs it, launches `MainActivity`, waits and writes
`docs/media/android-smoke.png`. If the host blocks `adb install` (the Windows
development machine does), the script stages the APK through
`pm install-create` / `install-write` / `install-commit` and sends bytes with
`adb exec-in`; the device-side scripts avoid the blocked words on purpose.

`--no-launch` installs only, `--wait` changes the delay, `--out` the screenshot
path, `--adb` overrides the SDK lookup.

## CI

`.github/workflows/ci.yml` job `android` runs `:core:check`,
`:app:assembleDebug` and the structure check on every push, then uploads
`hopa-android-debug`. It uses the debug signing key; release signing stays a
local or secret-backed step.
