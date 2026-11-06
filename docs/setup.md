# HOPA setup guide

Reproduce the HOPA development environment from a clean Windows 10/11 (64-bit)
machine. Verified against Huawei's official docs in November 2026. macOS notes are
included where they differ.

> **Version note (important):** Huawei switched the HarmonyOS API version scheme to
> SemVer (`X.Y.Z`) starting with **API 26.0.0**. It replaces the old `X.Y.Z(N)`
> form. HOPA targets the current stable **HarmonyOS SDK 26.0.0** (which is
> "HarmonyOS 6 and later"). Do not assume the old `API 20` numbering.

> **Local build note (2026-11-06):** the current Windows machine has DevEco
> Studio 6.1.1 and SDK **6.1.1 / API 24**. The project is set to
> `compileSdkVersion`/`targetSdkVersion` `6.1.1(24)` and `modelVersion` `6.1.1`
> so it builds here. The release target remains API 26; raise those four fields
> when SDK 26 is installed.

## 1. Pinned versions

| Component | Version | Notes |
| --- | --- | --- |
| HarmonyOS API | **26.0.0** | SemVer scheme |
| HarmonyOS SDK | **26.0.0** (OpenHarmony `Ohos_sdk_public 26.0.0.105`) | bundled with DevEco Studio |
| DevEco Studio | **26.0.0 Release** (`.865` patch, 2026-10-31) | Windows/macOS |
| Command Line Tools | **26.0.0.851** | for headless builds/CI |
| hvigorw | 6.26.8 | |
| ohpm | 26.0.0.630 | |
| codelinter | 6.0.240 | |
| hstack | 6.1.0 | |
| hdc | 3.2.0f | |
| HarmonyOS Emulator | 26.0.0.402 | |
| Bundled Node.js | 24.14.1 (LTS line) | do not replace the bundled copy |
| Python | 3.12.x (>= 3.11) | for `pc-agent/`, `bench/` and `agent/` |

Official version overview:
<https://developer.huawei.com/consumer/en/doc/doccenter-release-notes/overview-2600>

## 2. Hardware / OS requirements

DevEco Studio (Windows): Windows 10/11 64-bit, 16 GB RAM, 100 GB free disk,
1280×800+ display. Confirm your machine meets these before installing.

Emulator (Windows), from Huawei's emulator requirements:

- Windows 10 Pro/Enterprise/Education or later, build **≥ 10.0.18363**.
- 64-bit CPU with **SLAT**, **AES**, and **VT-x/AMD-V**; CPU from 2017 or later.
- **Hyper-V + Windows Hypervisor Platform + Virtual Machine Platform** enabled.
- The emulator **cannot run inside a VM** (no nested virtualization).
- 16 GB RAM min, 32 GB recommended; 16 GB free disk min.
- GPU with OpenGL 4.1+.
- Huawei **does not recommend Intel U-series CPUs** (and similar low-power parts) for the
  emulator due to performance. It is not a hard block, but expect slow boots.

Enable the three Windows features (admin PowerShell), then reboot:

```powershell
dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart
dism /online /enable-feature /featurename:HypervisorPlatform /all /norestart
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# if the emulator still reports "Hyper-V not enabled":
bcdedit /set hypervisorlaunchtype auto
# then reboot
```

Check: `Task Manager → Performance → CPU → Virtualization: Enabled`.

## 3. Python 3.11+ and Node LTS

Python (install 3.12.x or any 3.11+):

```powershell
winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
python --version
python -m pip --version
```

Node: use the **Node.js bundled with DevEco Studio / Command Line Tools** for
HarmonyOS builds. For the Python-side tooling any current Node LTS is fine.
Do not point `hvigorw` at a different Node than the
one shipped with the toolchain.

## 4. DevEco Studio (GUI + bundled SDK)

1. Sign in at <https://developer.huawei.com/consumer/en/download/> with a Huawei
   developer account.
2. Download **DevEco Studio → Windows (64-bit)**, version 26.0.0.
3. Accept the HarmonyOS SDK License Agreement.
4. Run the installer and accept the license agreements. Default path:
   `C:\Program Files\Huawei\DevEco Studio`.
5. On first launch, sign in again if prompted and let the IDE finish installing the
   bundled **HarmonyOS SDK 26.0.0**.

Verify in the IDE: `Help → About DevEco Studio` and `Help → About HarmonyOS SDK`.

## 5. Command Line Tools (headless)

1. On the same download centre page, download **Command Line Tools for HarmonyOS →
   Windows (64-bit)**: `commandline-tools-windows-x64-26.0.0.851.zip` (~2.7 GB).
2. Extract to a stable path, e.g. `C:\HarmonyOS\command-line-tools`. Keep the
   internal layout intact.
3. Expected layout after extraction:

```
C:\HarmonyOS\command-line-tools\
├── bin\                 # hvigorw, ohpm, codelinter, hstack wrappers
├── sdk\default\...      # HarmonyOS SDK 26.0.0
├── tool\node\           # bundled Node 24.14.1
└── tools\emulator\      # emulator CLI (26.0.0.402)
```

### Environment variables and PATH

Add these **user** environment variables (adjust the root if you extracted
elsewhere). Only `DEVECO_SDK_HOME` is needed for CLI builds; do not set
`HOS_SDK_HOME`/`DEVECO_SDK_HOME` when running local unit tests (see §8).

```powershell
$CLT = 'C:\HarmonyOS\command-line-tools'
[Environment]::SetEnvironmentVariable('DEVECO_SDK_HOME', "$CLT\sdk", 'User')
[Environment]::SetEnvironmentVariable('HOPA_CLT_HOME', $CLT, 'User')

$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$add = @("$CLT\bin", "$CLT\sdk\default\openharmony\toolchains", "$CLT\tools\emulator")
[Environment]::SetEnvironmentVariable('Path', (($userPath -split ';' | Where-Object { $_ }) + $add | Select-Object -Unique) -join ';', 'User')
```

Open a **new** terminal after changing env vars, then verify:

```powershell
where.exe hdc
where.exe ohpm
where.exe hvigorw
where.exe codelinter
hdc -v
ohpm -v
hvigorw --version
```

If you also want the IDE's tools on PATH, prepend
`C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin` and
`...\tools\ohpm\bin`, but prefer the Command Line Tools copies for CLI builds.

## 6. Emulator

1. Open **DevEco Studio → Tools → Device Manager** (or the Device Manager icon).
2. Accept the HarmonyOS Software License and Service Agreement.
3. Click **+ New Emulator** (or the download icon next to an image).
4. Choose **Phone**, then the newest **HarmonyOS 26.0.0** image (or the newest
   release available in your region/account). Download the image (~2 GB; allow
   ~12 GB to run).
5. Configure: name `hopa-phone`, RAM 4 GB+ (6–8 GB preferred), storage 16 GB+.
6. Start it. First boot can take several minutes on a U-series CPU.
7. Confirm from a terminal:

```powershell
hdc list targets
# expected: 127.0.0.1:5555   (or similar); [Empty] means nothing connected
```

CLI alternative (Command Line Tools ≥ 26.0.0):

```powershell
Emulator -list
Emulator -start "hopa-phone" -instancePath <path> -imageRoot <sdk-image-path>
```

## 7. Physical HarmonyOS 6+ device

1. **Enable Developer mode:** `Settings → About phone → Software information` and
   tap **Version number** 7 times. Enter the screen lock PIN if asked.
2. `Settings → System → Developer options` → enable **USB debugging**.
3. Connect by USB. On the phone, accept the **"Allow USB debugging?"** prompt
   (check "Always allow from this computer").
4. Confirm:

```powershell
hdc list targets
```

5. **Wireless debugging** (optional): `Developer options → Wireless debugging`,
   enable it, then either scan the pairing QR or use:

```powershell
hdc tconn <phone-ip>:<port>          # connect (no pairing needed on same LAN if enabled)
hdc tconn <phone-ip>:<pair-port>     # pairing port, if the device shows one
```

Keep the phone unlocked and on the same network. For payment testing, use a test
account and a device you are willing to reset.

## 8. Verify the whole setup

```powershell
# device/emulator must be listed
hdc list targets

# component tree -> pull it
hdc shell uitest dumpLayout -p /data/local/tmp/layout.json
hdc file recv /data/local/tmp/layout.json .\layout.json

# screenshot (faster than uitest screenCap)
hdc shell snapshot_display -f /data/local/tmp/screen.jpeg
hdc file recv /data/local/tmp/screen.jpeg .\screen.jpeg

# headless build
cd app
hvigorw assembleHap --no-daemon

# reference observation (device required)
hopa-agent observe --json

# core unit tests (Windows/macOS only; NOT supported on Linux)
hvigorw test -p module=core@default --no-daemon -p coverage=false
```

Result files:

- HAP: `app/entry/build/default/outputs/default/entry-default-signed.hap`
- Local test results: `app/core/.test/default/intermediates/test/coverage_data/test_result.txt`
- Local test report: `app/core/.test/default/outputs/test/reports/index.html`

## 9. Python-side tooling

```powershell
cd pc-agent
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -U pip
pip install -e ".[dev]"

cd ..\bench
pip install -e ".[dev]"

cd ..\agent
pip install -e ".[dev]"

cd ..
pc-agent devices
pc-agent dump --out layout.json
hopa-agent observe --json
pytest pc-agent
pytest bench
pytest agent
ruff check pc-agent bench agent
```

## 10. Troubleshooting

| Symptom | Fix |
| --- | --- |
| `hdc list targets` shows `[Empty]` | Start the emulator; enable USB debugging; accept the RSA prompt; `hdc kill` then retry. |
| Emulator: "Hyper-V not enabled" | Enable the three Windows features, run `bcdedit /set hypervisorlaunchtype auto`, reboot, enable VT-x in BIOS. |
| Emulator won't start on a VM | Unsupported — the emulator cannot run inside a VM. Use a physical host or a real device. |
| Emulator freezes / "Guest no response" / kernel panic `SceneBoard exits 4times` | Wipe data and cold boot; update the emulator; free host RAM; update the Intel GPU driver. See `docs/emulator-crash-2026-11-06.md`. |
| `SDK component missing` | Do not mix IDE hvigor with CLI SDK (or vice versa). Use the Command Line Tools `hvigorw` + its SDK. |
| `hvigorw test` hangs / fails | Unset `DEVECO_SDK_HOME` and `HOS_SDK_HOME`; Local Test is not supported on Linux. |
| `spawn java ENOENT` | Use the JBR bundled with DevEco Studio, or install JDK 17+. |
| Build uses wrong API level | Check `compileSdkVersion` (26.0.0) and `compatibleSdkVersion` (6.1.1 / API 24) in `app/build-profile.json5`. |
| `ohpm install` can't reach registry | Corporate proxy? Configure `ohpm config set registry` per official docs. |

## 11. What still needs a human

- Huawei developer account login (DevEco Studio, download centre, emulator license).
- Accepting the HarmonyOS SDK / Software License agreements.
- Automatic signing for a physical device (`Project Structure → Signing Configs →
  Automatically generate signature`).
- Enabling Developer mode / USB debugging and accepting the RSA prompt.
- Approving the ACL request for the accessibility capability (see
  `docs/architecture.md`).
