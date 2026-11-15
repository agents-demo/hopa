# HOPA Android setup guide

Reproduce the HOPA Android development environment from a clean Windows 10/11
(64-bit) machine. Written from a verified install on 2026-11-15; every command
below was run in that order on the reference machine.

Two different SDK levels appear in this guide, and that is deliberate:

- **API 37.0** is what the emulator image and platform-tools are on (the current
  Android release). It is only used to *run* the app.
- **API 35** is what `apps/android` *compiles against* (`compileSdk = 35`,
  `targetSdk = 35`, `minSdk = 30`). Install it even though it is not the newest.

macOS is possible but untested here; the only differences are the package
manager and the hypervisor (Apple's Hypervisor.framework replaces WHP).

## 1. Pinned versions

| Component | Version | Notes |
| --- | --- | --- |
| JDK (toolchain) | **Eclipse Temurin 17** (`17.0.21+9`) | `jvmToolchain(17)` in `packages/*`; what CI uses |
| JDK (daemon, optional) | Eclipse Temurin 21 (`21.0.13+9`) | only if you also build projects that need a newer JDK |
| Android Studio | **2026.2.2** (Rabbit 2) | bundles JBR 25 — see § 9 |
| Android SDK Platform | **37.0** (run) and **35** (compile) | |
| Build Tools | **34.0.0** (fetched by the Android build) and **36.0.0** (bundled with API 37) | 35.0.0 also works |
| Platform Tools (`adb`) | **37.0.1** | |
| Emulator | **37.2.13** | |
| Command-line Tools | **23.0.0** (`cmdline-tools/latest`) | `sdkmanager`, `avdmanager` |
| System image | `system-images;android-37.0;google_apis_playstore;x86_64` | Play Store image, no `adb root` |
| AVD | `Medium_Phone_API_37.0` (`medium_phone`, 1080×2400) | |
| Gradle | **8.11.1** (wrapper in `apps/android`) | nothing to install |
| AGP / Kotlin | **8.7.3** / **2.0.21** | in `gradle/libs.versions.toml` |
| Compose BOM | 2024.12.01 | |
| JVM target | 17 — bytecode and toolchain | |

The repo pins the build tool versions; only the JDK, Android Studio and SDK come
from this document. If `apps/android/gradle/wrapper/gradle-wrapper.properties`
changes, trust the wrapper, not this table.

## 2. Hardware and OS

- Windows 10/11 64-bit (verified on Windows 11 Pro `10.0.22631`).
- 16 GB RAM minimum, 32 GB comfortable (the emulator was given 2 GB).
- ~40 GB free disk: Studio ~5 GB, SDK ~12 GB with a system image, plus Gradle
  caches.
- CPU with VT-x/AMD-V enabled in the BIOS/UEFI.
- Any DX11/OpenGL 4.x GPU. An Intel Iris Xe (integrated) is sufficient; the
  emulator uses the host GPU through Vulkan/gfxstream.
- **A Windows VM will not work well** for the emulator: nested virtualisation is
  usually unavailable. Use a physical machine or a real phone.

You do **not** need HOPA's HarmonyOS toolchain (DevEco Studio, `hvigor`,
`hdc`) to build the Android client. That is
[`../harmony/setup.md`](../harmony/setup.md).

## 3. JDK 17 (and optionally 21)

**JDK 17 is required.** The shared JVM modules (`packages/core`,
`packages/capabilities`, `packages/data`) pin `jvmToolchain(17)`, and Gradle 8.x
will not satisfy a 17 toolchain with a 21 JDK — it wants an actual JDK 17 on
disk. CI uses Temurin 17 for the same reason.

```powershell
winget install --id EclipseAdoptium.Temurin.17.JDK -e `
  --accept-source-agreements --accept-package-agreements
```

Optional, and only if you also build projects that require a newer JVM
(Android Studio's own JBR 25 is not usable for older Gradle versions):

```powershell
winget install --id EclipseAdoptium.Temurin.21.JDK -e `
  --accept-source-agreements --accept-package-agreements
```

Then set `JAVA_HOME` to **17** (admin PowerShell). This matches CI and makes the
daemon and the toolchain the same install:

```powershell
[Environment]::SetEnvironmentVariable(
  'JAVA_HOME',
  'C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot',
  'Machine')
```

Verify in a **new** shell:

```powershell
java -version    # openjdk version "17.0.21" ... Temurin-17.0.21+9
```

If you keep `JAVA_HOME` on 21 instead, that is fine: Gradle 8.11.1 runs on it and
still finds the 17 toolchain, because it auto-detects installs under
`C:\Program Files\Eclipse Adoptium`. This combination was verified on the
reference machine. When in doubt, prefer 17 — fewer moving parts, and it is the
version the repo is tested with.

Gradle 8.11.1 accepts Java 8–23; AGP 8.7.3 requires 17+. Java 25 (Studio's
bundled JBR) is rejected by Gradle 8.9 and below.

## 4. Android Studio

```powershell
winget install --id Google.AndroidStudio -e `
  --accept-source-agreements --accept-package-agreements
```

Start it once and let the **setup wizard** finish. It creates the SDK at
`%LOCALAPPDATA%\Android\Sdk` and installs `platform-tools`, `cmdline-tools`,
`build-tools` and the current platform for you. Decline the optional
"Android Virtual Device" download if you prefer to create it yourself (§ 8).

Check the SDK location:

```powershell
Test-Path "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat"
```

If the wizard put it elsewhere, use that path instead of `%LOCALAPPDATA%` for
the rest of this guide and set `sdk.dir` in `apps/android/local.properties`
(gitignored) rather than editing tracked files.

## 5. SDK packages

Accept the licences once, then install the exact package set:

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$sm  = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

& $sm --licenses                     # press y for each

& $sm "platform-tools" `
      "emulator" `
      "cmdline-tools;latest" `
      "platforms;android-37.0" `
      "build-tools;36.0.0" `
      "system-images;android-37.0;google_apis_playstore;x86_64" `
      "sources;android-37.0"

# what apps/android compiles against
& $sm "platforms;android-35" "build-tools;34.0.0" "build-tools;35.0.0"
```

Notes:

- Package IDs for API 37 use a dot: `platforms;android-37.0`, not `android-37`.
- API 35 has no dot: `platforms;android-35`.
- `sources;android-37.0` is optional (IDE navigation into the framework).
- AGP 8.7.3 will also install a missing platform or build-tools by itself on the
  first build: on the reference machine it fetched `build-tools;34.0.0` and
  `platforms;android-35` before compiling. Installing them explicitly keeps the
  first build predictable and works offline.
- The plain `google_apis` (rootable, no Play Store) image may not be published
  for API 37 in your channel. You do not need it: HOPA needs no `adb root`.
  Only `google_apis_playstore` is used here.

Verify:

```powershell
& $sm --list_installed
```

Compare against § 1. `sdkmanager --list` (the remote catalogue) can fail behind a
corporate proxy; `--list_installed` still works and is enough.

## 6. Hypervisor and reboot

The emulator needs **Windows Hypervisor Platform**. Full Hyper-V is not required
and is not what was used.

```powershell
dism /online /enable-feature /featurename:HypervisorPlatform /all /norestart
# if the emulator still reports no acceleration after a reboot:
bcdedit /set hypervisorlaunchtype auto
```

Reboot. Then confirm:

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
& "$sdk\emulator\emulator-check.exe" accel
# accel:
# 0
# WHPX(10.0.22631) is installed and usable.
```

Use `emulator-check.exe accel` — **not** `emulator -accel-check`. The latter hangs
on this class of machine.

## 7. Environment variables

Set at **user** level so the tools work in every shell and in Android Studio's
terminal:

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User')

$path = [Environment]::GetEnvironmentVariable('Path','User')
$add  = @("$sdk\platform-tools", "$sdk\cmdline-tools\latest\bin", "$sdk\emulator")
[Environment]::SetEnvironmentVariable(
  'Path', (($path -split ';' | Where-Object { $_ }) + $add | Select-Object -Unique) -join ';',
  'User')
```

Open a new terminal and verify:

```powershell
where.exe adb          # ...\platform-tools\adb.exe
where.exe emulator     # ...\emulator\emulator.exe
where.exe sdkmanager   # ...\cmdline-tools\latest\bin\sdkmanager.bat
```

`ANDROID_HOME` is enough for Gradle; `local.properties` is optional and stays
out of git.

## 8. Emulator

Create the AVD that the evidence and screenshots use:

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
& "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd `
  -n Medium_Phone_API_37.0 `
  -k "system-images;android-37.0;google_apis_playstore;x86_64" `
  -d medium_phone
```

`medium_phone` is the generic 1080×2400 profile (`avdmanager list device` shows
Pixel profiles too; `pixel_10` also works). The AVD created by Studio's Device
Manager is equivalent.

Launch it **detached** so it does not die with the shell that started it:

```powershell
Start-Process "$sdk\emulator\emulator.exe" `
  -ArgumentList '-avd','Medium_Phone_API_37.0'
```

Wait for boot and verify:

```powershell
adb wait-for-device
adb shell getprop sys.boot_completed   # 1
adb shell getprop ro.build.version.sdk # 37
adb shell wm size                      # Physical size: 1080x2400
adb devices -l                         # emulator-5554  device
```

Screenshot, the same way the benchmark path does it:

```powershell
adb shell screencap -p /sdcard/s.png
adb pull /sdcard/s.png .\s.png
adb shell rm /sdcard/s.png
```

First boot takes minutes; later boots restore the `default_boot` snapshot and are
much faster. A cold boot with a clean state: `emulator -avd ... -no-snapshot-load`.

## 9. Build and run HOPA

From the repo root:

```powershell
cd apps\android
.\gradlew.bat :app:assembleDebug
```

The wrapper downloads Gradle 8.11.1 on first use. The daemon runs on
`JAVA_HOME`; the shared modules compile with the JDK 17 toolchain. The first build
also resolves dependencies and may install a missing SDK package, so allow a few
minutes. Cold timings on the reference machine (i7-1355U, 32 GB): ~4.5 min for
`assembleDebug`, ~2.5 min for `test`; later builds are much faster. The APK lands
in `apps\android\app\build\outputs\apk\debug\`.

Install on the running emulator and start it:

```powershell
.\gradlew.bat :app:installDebug
adb shell am start -n com.hopa.android/.MainActivity
adb logcat -s HOPA:* AndroidRuntime:E
```

Useful tasks:

| Task | What it does |
| --- | --- |
| `:app:assembleDebug` | build the debug APK |
| `:app:installDebug` | install on the attached device |
| `test` | JVM unit tests (loop, gate, records, conformance) |
| `:app:connectedDebugAndroidTest` | instrumented tests on the emulator |
| `:app:dependencies` | resolve the version catalog |

### Gradle JDK in Android Studio

Studio 2026.2.2 runs on **JBR 25**, which Gradle 8.11.1 accepts but older
projects do not. For each project, pin the Gradle JDK explicitly: **17** for
`apps/android` (matches the toolchain and CI), **21** for projects already on a
JDK 21 toolchain.

**Settings** (`Ctrl+Alt+S`) → **Build, Execution, Deployment** → **Build Tools** →
**Gradle** → **Gradle JDK** → **Eclipse Temurin 17.0.21** (or `21.0.13`) →
**Apply** → **Sync**.

That writes the project's own `.idea/gradle.xml` (gitignored) and leaves global
defaults alone. Do this per project — do **not** set
`org.gradle.java.home` in a tracked `gradle.properties`, and do not create a
global `~/.gradle/gradle.properties` just to work around one old project.

Symptoms of the wrong JDK:

```
The project's Gradle version Gradle 8.9 is incompatible with the Gradle JVM
version 25. To fix this, select a JVM version that is at least 8 and at most 22.
```

Fix the JDK, not the Gradle version. Upgrading Gradle alone breaks the project's
AGP/Kotlin combination.

### Java toolchains

`apps/android` also compiles three pure-JVM modules from `packages/`, and they pin
`jvmToolchain(17)`. That is independent of the daemon JVM: Gradle needs a real
JDK 17 on disk even when it runs on 21. If it is missing you get

```
Failed to calculate the value of task ':core:compileJava' property 'javaCompiler'.
> Cannot find a Java installation on your machine matching this tasks requirements:
  {languageVersion=17, vendor=any vendor, implementation=vendor-specific} for WINDOWS on x86_64.
```

Install Temurin 17 (§ 3). Do not "fix" it by changing the Gradle JDK to 21 or by
adding a toolchain resolver — the shared modules must stay buildable by the
Windows sidecar and by CI, which use 17.

## 10. Verify the whole setup

| Check | Command | Expected |
| --- | --- | --- |
| JDK | `java -version` | `17.0.21` Temurin (or 21 as daemon) |
| JDK 17 present | `Test-Path "C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot"` | `True` |
| SDK root | `echo $env:ANDROID_HOME` | `...\AppData\Local\Android\Sdk` |
| adb | `adb version` | `1.0.41` / 37.0.1 |
| acceleration | `emulator-check.exe accel` | `WHPX ... usable` |
| AVD exists | `emulator -list-avds` | `Medium_Phone_API_37.0` |
| device | `adb devices -l` | `emulator-5554  device` |
| Android version | `adb shell getprop ro.build.version.release` | `17` |
| platform 35 | `Test-Path "$env:ANDROID_HOME\platforms\android-35"` | `True` |
| build | `.\gradlew.bat :app:assembleDebug` | `BUILD SUCCESSFUL` |
| tests | `.\gradlew.bat test` | `BUILD SUCCESSFUL` |

## 11. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Gradle 8.9 is incompatible with Gradle JVM 25` | Pin the project's Gradle JDK to Temurin 17 (or 21) (§ 9). Do not upgrade Gradle. |
| `Unable to locate adb` / `adb` not found | `ANDROID_HOME`/PATH not set, or a shell opened before § 7. Restart the terminal, then `adb kill-server; adb start-server`. |
| Gradle: `SDK location not found` | Set `ANDROID_HOME`, or add `sdk.dir` to `apps/android/local.properties` (gitignored). |
| Gradle: `Failed to find target android-35` | Install `platforms;android-35` (§ 5). The emulator's API 37 is not a substitute. |
| `Cannot find a Java installation ... {languageVersion=17}` | No JDK 17 on disk. `jvmToolchain(17)` in `packages/*` needs one (§ 3); the daemon JDK is irrelevant. |
| `This version only understands SDK XML versions up to 3 but ... version 4 was encountered` | AGP 8.7.3 reading metadata written by newer tools. Benign; the build continues and installs the platform. |
| Studio still uses JBR 25 after the change | **File → Invalidate Caches… → Restart**, then sync again; a stale Gradle daemon can hold the old JVM. |
| `emulator -accel-check` hangs | Use `emulator-check.exe accel` instead. |
| `[Vulkan Loader] WARNING ... VK_LAYER_OBS_HOOK` | OBS Studio's Vulkan layer; the emulator disables it on purpose. Noise. |
| `The emulator now requires a signed jwt token for gRPC` | Only matters for the emulator gRPC API. Noise. |
| `Critical: Failed to load opengl32sw` / `Software OpenGL failed` | Fallback message; the host GPU is used. Noise. |
| `Vulkan 1.4 is not supported for the guest` | Normal for the API 37 image; the guest uses GLES. Noise. |
| `Unable to strip the following libraries, packaging them as they are` | No NDK/`strip` tool installed; AGP packages the bundled `.so` files as-is. Harmless — HOPA needs no NDK. |
| `adb protocol fault (couldn't read status length)` | Startup race with the adb server. `adb kill-server; adb start-server; adb devices`. |
| `UpdateLayeredWindowIndirect failed ... A device attached to the system is not functioning` | Windows window-painting hiccup (RDP, session lock, GPU driver). Harmless; relaunch with `-gpu swiftshader_indirect` if the window stays blank. |
| Emulator window disappears when a terminal closes | It was started as a child of that shell. Launch with `Start-Process`, or from Studio's Device Manager. |
| Emulator feels slow / fans spin up | Integrated GPUs are fine but not fast. Use a snapshot, keep it open, or run on a real device over ADB. |
| `sdkmanager --list` errors | Proxy/network. `--list_installed` still works; use Studio's SDK Manager to refresh. |
| Play Store image: `adb root` refused | Expected. Play images are not rootable; HOPA does not need root. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | A differently-signed build is installed. `adb uninstall com.hopa.android`, then install again. |

## 12. Optional: OpenCode as an ACP agent in Android Studio

Only needed if you use the **Agent** tab. The agent uses OpenCode's own
credentials and config (`%USERPROFILE%\.config\opencode`,
`%USERPROFILE%\.local\share\opencode\auth.json`), not Android Studio's.

```powershell
npm install -g opencode-ai
opencode --version      # 1.18.30 at the time of writing
opencode auth login     # e.g. DeepSeek
```

Point the ACP config at the **native executable**, not the `opencode.cmd`
shim — Studio launches the command directly and batch shims often fail:

```powershell
(Get-ChildItem "$env:APPDATA\npm\node_modules\opencode-ai\bin\opencode.exe").FullName
```

Studio 2026.2.2 keeps the file at `%USERPROFILE%\.android\studio\agent\acp.json`
(older builds use `%USERPROFILE%\.jetbrains\acp.json`). Add one entry:

```json
{
  "agent_servers": {
    "OpenCode": {
      "command": "C:\\Users\\<you>\\AppData\\Roaming\\npm\\node_modules\\opencode-ai\\bin\\opencode.exe",
      "args": ["acp"]
    }
  }
}
```

Restart Studio; the agent appears in the Agent tab's selector. Verify the binary
speaks ACP before blaming Studio:

```powershell
'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1}}' |
  & "$env:APPDATA\npm\node_modules\opencode-ai\bin\opencode.exe" acp
# {"result":{"protocolVersion":1,...,"agentInfo":{"name":"OpenCode",...}}}
```

If the agent exits immediately, add `"--print-logs"` before `"acp"`. Stdout stays
protocol-only; logs go to stderr and **Get ACP Logs** captures them.

The path above is per-machine and version-specific. OpenCode reads `AGENTS.md`;
this repo's rules live in `CLAUDE.md`, so add an `AGENTS.md` that points at it if
you want the agent to follow the golden rules.

## 13. What still needs a human

- Android Studio first-run wizard and any licence dialogs.
- `sdkmanager --licenses` acceptance (no script can do this unattended).
- Optional Google Play sign-in (only for Play Store features, not for HOPA).
- Unlocking the emulator after it sleeps.
- `opencode auth login` if § 12 is used.
- Granting the accessibility service, if you test the on-device path; that is an
  in-app flow, not a host setup step.

## 14. Unattended install (copy-paste)

For a fresh Windows box where nothing above is installed yet. Run as admin; it
still stops at the licence prompts and the reboot.

```powershell
# 3. JDK 17 (required) and 21 (optional)
winget install --id EclipseAdoptium.Temurin.17.JDK -e `
  --accept-source-agreements --accept-package-agreements
[Environment]::SetEnvironmentVariable(
  'JAVA_HOME','C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot','Machine')
# optional, for projects that need a newer JVM
# winget install --id EclipseAdoptium.Temurin.21.JDK -e `
#   --accept-source-agreements --accept-package-agreements

# 4. Android Studio (run its wizard once afterwards)
winget install --id Google.AndroidStudio -e `
  --accept-source-agreements --accept-package-agreements

# 5. SDK packages
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$sm  = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"
& $sm --licenses
& $sm "platform-tools" "emulator" "cmdline-tools;latest" `
      "platforms;android-37.0" "build-tools;36.0.0" `
      "system-images;android-37.0;google_apis_playstore;x86_64" `
      "sources;android-37.0" "platforms;android-35" "build-tools;34.0.0" "build-tools;35.0.0"

# 6. Hypervisor (then reboot)
dism /online /enable-feature /featurename:HypervisorPlatform /all /norestart

# 7. Environment
[Environment]::SetEnvironmentVariable('ANDROID_HOME',$sdk,'User')
$path = [Environment]::GetEnvironmentVariable('Path','User')
$add  = @("$sdk\platform-tools","$sdk\cmdline-tools\latest\bin","$sdk\emulator")
[Environment]::SetEnvironmentVariable(
  'Path',(($path -split ';' | Where-Object { $_ }) + $add | Select-Object -Unique) -join ';','User')

# 8. AVD
& "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd `
  -n Medium_Phone_API_37.0 `
  -k "system-images;android-37.0;google_apis_playstore;x86_64" `
  -d medium_phone

# 10. Verify (new shell after the reboot)
java -version
adb version
& "$sdk\emulator\emulator-check.exe" accel
```

Then § 9: open `apps/android` in Studio, set the project Gradle JDK to Temurin 21,
sync, and run.

## Related

- [Android guide](README.md) — how the loop runs and how the app acts
- [HarmonyOS setup](../harmony/setup.md) — the frozen toolchain
- [Android plan](../../project/plan/android/README.md) — what is built and why
- [Android architecture](../../design/architecture/apps-android.md)
