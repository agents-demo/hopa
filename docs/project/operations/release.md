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
