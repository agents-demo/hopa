# P6 package evidence

Date: 2026-11-24. Host: Windows 11 x64, .NET 10, JDK 21.0.11, WiX 5.0.2.

## Build

```powershell
$env:HOPA_JLINK_HOME = "C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot"
$env:PATH = "$env:USERPROFILE\.dotnet\tools;$env:PATH"   # wix 5
powershell -NoProfile -ExecutionPolicy Bypass -File tools/scripts/windows-package.ps1
```

## Artifact

| File | Bytes | SHA-256 |
|---|---:|---|
| `hopa-windows-0.1.0.msi` | 111,435,385 | `74895BA7F518BA0AE3DD9EB4BF024F52AB7007CFEF90509D5DE4E02E2020222E` |
| `hopa-windows-0.1.0.zip` | 124,405,097 | `C6F433E6A52AFA3B3DFAE8E64C8B70A0761CD45F8B9B63CBDFAB550279373EFB` |

The script writes both `*.sha256` files and refuses a JDK whose `release` file
is not 21.

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

- **Signing** the exe and MSI (`signtool verify /pa`), timestamped.
- **Clean Windows VM** install: one PC turn and one phone-approved turn.
- A UI/automation smoke on that VM; the hosted desktop job cannot provide UIA.
