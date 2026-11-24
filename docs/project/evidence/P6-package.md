# P6 package evidence

Date: 2026-11-24. Host: Windows 11 x64, .NET 10, JDK 21.0.11, WiX 5.0.2.

## Build

```powershell
$env:HOPA_JLINK_HOME = "C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot"
$env:PATH = "$env:USERPROFILE\.dotnet\tools;$env:PATH"   # wix 5
powershell -NoProfile -ExecutionPolicy Bypass -File tools/scripts/windows-package.ps1
```

## Artifact

The first local package (before the signing hook) was an unsigned build without
a suffix:

| File | Bytes | SHA-256 |
|---|---:|---|
| `hopa-windows-0.1.0.msi` | 111,435,385 | `74895BA7F518BA0AE3DD9EB4BF024F52AB7007CFEF90509D5DE4E02E2020222E` |
| `hopa-windows-0.1.0.zip` | 124,405,097 | `C6F433E6A52AFA3B3DFAE8E64C8B70A0761CD45F8B9B63CBDFAB550279373EFB` |

Current unsigned builds are named `hopa-windows-0.1.0-unsigned.{zip,msi}`; the
script refuses a JDK whose `release` file is not 21 and writes both
`*.sha256` files.

## Signing hook test (self-signed, not a release)

A temporary `CN=HOPA Test Signing` certificate was created in `CurrentUser\My`,
exported to a PFX, and trusted in `CurrentUser\Root` for the duration of the
test:

```powershell
$env:HOPA_SIGN_PFX_PASSWORD = "hopa-test"
tools/scripts/windows-package.ps1 -CertificatePath <temporary.pfx>
```

Result:

- exe signed and `signtool verify /pa` passed;
- MSI signed and verified;
- timestamp: RFC3161, SHA-256;
- signed MSI: 111,452,160 bytes, SHA-256
  `A50F6CED3386C7C1C110D7324187AA4F867F03B86D6C17585944FC9F8E600602`;
- test certificate and PFX removed afterwards.

This proves the hook and the exe+MSI order. It does **not** prove release
identity: a self-signed root is not a trusted publisher, and no real
certificate/Trusted Signing profile exists yet.

## Payload check

`msiexec /a <msi> /qn TARGETDIR=<dir>` succeeded. The extract contains:

- `HOPA\Hopa.Windows.exe`
- `HOPA\sidecar\lib` (agent/backend/bridge jars and dependencies)
- `HOPA\runtime\bin\java.exe` with `JAVA_VERSION="21.0.11"`

That proves the installer carries the private runtime and sidecar, not a
machine-wide Java dependency. It is **not** a clean-VM install test: an
administrative extract does not exercise MSI registration, shortcuts, upgrades
or a machine without .NET.

## CI

The Windows job installs WiX 5, pins .NET 10.0.201, installs JDK 21 for jlink,
runs `windows-package.ps1` without `-SkipMsi`, and uploads:

- `hopa-windows-0.1.0.zip`
- `hopa-windows-0.1.0.zip.sha256`
- `hopa-windows-0.1.0.msi`
- `hopa-windows-0.1.0.msi.sha256`

## Still open

- **Real release identity**: PFX/certificate-store/Trusted Signing and a
  trusted publisher. The hook itself is tested with a self-signed certificate.
- **Clean Windows VM** install: one PC turn and one phone-approved turn.
- A UI/automation smoke on that VM; the hosted desktop job cannot provide UIA.

CI reads `WINDOWS_CERTIFICATE_BASE64` and `WINDOWS_CERTIFICATE_PASSWORD` when
they exist; otherwise it builds the clearly-labelled `-unsigned` artifacts.
