# Release guide

Status: **not released.** This is the checklist and the runbook. The HAP is
currently unsigned, API 26 is not installed, and no AppGallery submission has
been made.

## Version

- App: `0.1.0` (`apps/harmony/AppScope/app.json5`)
- Brain: `0.1.0`
- Contracts: `v1`
- SBOM: `docs/project/operations/sbom.json`

## Install (development)

1. Build with DevEco 6.1.1 / API 24:

```powershell
$dev='C:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME="$dev\sdk"
$env:JAVA_HOME="$dev\jbr"
$env:PATH="$dev\tools\node;$dev\tools\hvigor\bin;$dev\tools\ohpm\bin;$dev\sdk\default\openharmony\toolchains;$env:PATH"
cd apps/harmony
ohpm install
hvigorw assembleHap --no-daemon
```

2. The output is `apps/harmony/phone/build/default/outputs/default/entry-default-unsigned.hap`.
3. Sign it in DevEco (`Project Structure → Signing Configs`) before installing.
4. Install with `hdc install <signed.hap>`.

## Upgrade

- Keep the previous HAP and the signing config.
- Records and knowledge carry a schema version; run the migration if the version
  changes.
- Do not downgrade a knowledge file without a backup.

## Rollback

1. Stop the app.
2. Reinstall the previous signed HAP.
3. Restore the previous knowledge version (it is pinned per release).
4. Keep the new run records; they are append-only.

## FAQ and troubleshooting

| Symptom | Check |
|---|---|
| `hdc list targets` is empty | Emulator running? USB debugging? Accept the RSA prompt. |
| `uitest dumpLayout` fails | Screen locked or no foreground window. Unlock and open an app. |
| HAP will not install | Is it signed for this device/profiled? |
| Model calls fail | API key, base URL, network, provider status. |
| Payment prompt appears too often | Expected: classification is fail-closed. |
| App cannot control other apps | Accessibility service not enabled or ACL not approved. |

## Support

- Issues: GitHub issues on the fork.
- Security: private advisory, see `SECURITY.md`.
- Response: best effort; no SLA before a public release.

## Monitoring

Planned dashboards:

- crash-free sessions;
- model error rate;
- step latency p50/p95;
- payment prompts and denials;
- ACL-unavailable rate.

No dashboard is deployed yet.

## Post-release checklist

- [ ] Signed HAP installs on a clean device.
- [ ] Upgrade from the previous version works.
- [ ] Rollback works.
- [ ] Crash reporting is opt-in and symbols are uploaded.
- [ ] Privacy and security pages are linked from the store listing.
- [ ] Monitoring has run for 7 days with no P0 incident.
- [ ] Support has the runbook and the redacted-log tool.

## Archive plan

- Tag the release `app-v0.1.0`, `brain-v0.1.0`, `contracts-v1`.
- Archive the signed HAP, SBOM, NOTICE and the bench report together.
- Keep the source repository public and the fork as the build record.
- Do not delete the knowledge version used by the release.

## Android (0.1.0)

The Android client ships as a sideloaded APK, independent of the HAP above.

| Item | Value |
|---|---|
| Package | `com.hopa.android` |
| Version | `0.1.0` (versionCode 1) |
| minSdk / target | 30 / 35 |
| Artifact | `hopa-0.1.0-debug.apk` (debug key) |
| Release asset | `android-0.1.0-debug` in the fork's releases |

Build and verify:

```powershell
cd apps/android
.\gradlew.bat :core:check :capabilities:test :capabilities-android:testDebugUnitTest :data:test :app:testDebugUnitTest :app:assembleDebug
python tools/scripts/android-smoke.py --serial <serial>
python tools/checks/check-android-structure.py
```

Release signing, when a keystore exists:

1. Put `apps/android/keystore.properties` with `storeFile`, `storePassword`,
   `keyAlias`, `keyPassword`; the file and the keystore are gitignored.
2. `.\gradlew.bat :app:assembleRelease` then
   `apksigner verify --print-certs ...` must print the release DN, not
   `CN=Android Debug`.
3. Keep the signed APK, its SHA-256 and the commit together.

Publish:

1. Copy `app-debug.apk` over the asset in `android-0.1.0-debug`.
2. Update the release notes with the size, SHA-256 and commit.
3. Record the same in `docs/project/releases/0.1.0-android.md`.

Checklist for this release:

- [x] Debug APK installs on an emulator and launches (smoke script).
- [x] CI builds the APK, `:core:check` and the capabilities/app tests.
- [x] Structure check, plan lint and links are clean.
- [x] SHA-256 and commit recorded in the release notes.
- [ ] Release keystore in CI (secrets) and a signed APK on a clean phone.
- [ ] A real-phone accessibility run.
