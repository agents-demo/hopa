# Local debug signing

HOPA does **not** need a Huawei developer account to run on an emulator or a
debug device. The DevEco / Command Line Tools SDK ships a complete OpenHarmony
debug signing kit, and `scripts/sign-app` drives it end to end.

## What the SDK provides

`<sdk>/default/openharmony/toolchains/lib/` contains:

| File | Purpose |
|---|---|
| `hap-sign-tool.jar` | key, certificate, profile and HAP signing |
| `OpenHarmony.p12` | the OpenHarmony debug keystore (password `123456`) |
| `OpenHarmonyProfileDebug.pem` | profile-signing certificate chain |
| `UnsgnedDebugProfileTemplate.json` | the debug profile template |

The keystore holds `openharmony application root ca`,
`openharmony application ca` and `openharmony application profile debug`.
Those keys are public test material: they sign only debug profiles, and a device
must still have its UDID in the profile before it will install the HAP.

## Run it

```powershell
.\scripts\build.ps1
.\scripts\sign-app.ps1 -Install
```

```bash
./scripts/build.sh
./scripts/sign-app.sh --install
```

The script:

1. copies the SDK keystore to `signing/OpenHarmony.p12`;
2. creates an ECC P-256 app key `hopa-app-debug` if it is missing;
3. issues an app certificate chain from `OpenHarmony Application CA`;
4. builds `signing/profile.json` from the template with the bundle name
   `com.hopa.agent` and the connected device's UDID;
5. signs the profile into `signing/profile.p7b`;
6. signs `entry-default-unsigned.hap` into `entry-default-signed.hap`;
7. verifies the result;
8. with `-Install` / `--install`, runs `hdc install -r`.

Everything the script writes is under `signing/`, which is gitignored. Nothing
secret is committed, and the script is safe to re-run.

## Two pitfalls that cost time

- **Certificate chain order.** `generate-app-cert` wants C, O, OU, CN. It
  reverses the DN internally before comparing it with the CA subject. Writing
  `CN=...` first produces a valid-looking certificate that fails later with
  `verify certificate chain issuer subject failed`.
- **The leaf must match the profile.** `sign-app` refuses a profile whose
  `development-certificate` is not the leaf of `appCertFile`, and it refuses a
  leaf-only app certificate with `Profile cert must a cert chain`. Always embed
  the first certificate of the generated chain.

## Scope and limits

- A **debug** profile only installs on devices whose UDID it lists. Use
  `-Udids` / `--udid` to add another device.
- This is not a release signature. Store distribution still needs a Huawei
  developer account and a release profile (`OpenHarmonyProfileRelease.pem`).
- The accessibility ACL is unrelated to signing; it must be filed separately.
- `signing/` must never be committed. `.gitignore` already blocks it.
