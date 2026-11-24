param(
    [string]$Output = "out/windows",
    [string]$JdkHome = "",
    [switch]$SkipMsi
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $root $Output
$stage = Join-Path $out "hopa-windows-0.1.0"
$sidecar = Join-Path $root "apps/windows/sidecar"
$client = Join-Path $root "apps/windows/Hopa.Windows/Hopa.Windows.csproj"
$jdk = if ($JdkHome) {
    $JdkHome
} elseif ($env:HOPA_JLINK_HOME) {
    $env:HOPA_JLINK_HOME
} else {
    $env:JAVA_HOME
}

if (-not $jdk) {
    throw "Set -JdkHome or HOPA_JLINK_HOME to a JDK 21 installation for the jlink runtime."
}

$jdkRelease = Join-Path $jdk "release"
if (-not (Test-Path $jdkRelease)) {
    throw "JDK home has no release file: $jdk"
}

$jdkReleaseText = Get-Content $jdkRelease -Raw
if ($jdkReleaseText -notmatch 'JAVA_VERSION="21\.') {
    throw "The jlink runtime must be JDK 21; '$jdk' is not. Set HOPA_JLINK_HOME or -JdkHome."
}

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

Write-Host "1/5 sidecar"
& (Join-Path $root "apps/android/gradlew.bat") -p $sidecar installDist --no-daemon
if ($LASTEXITCODE -ne 0) { throw "installDist failed" }
New-Item -ItemType Directory -Path (Join-Path $stage "sidecar") -Force | Out-Null
Copy-Item (Join-Path $sidecar "build/install/hopa-windows-sidecar/lib") (Join-Path $stage "sidecar/lib") -Recurse -Force
Copy-Item (Join-Path $root "LICENSE") (Join-Path $stage "LICENSE.txt") -Force

Write-Host "2/5 publish"
dotnet publish $client -c Release -r win-x64 --self-contained -o $stage
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

# The package is the product. The developer exe, the checks and the test
# fixtures are separate artifacts; a leak here would ship them to clients.
$forbidden = @(
    "Hopa.Windows.DevTools.exe",
    "Hopa.Windows.DevTools.dll",
    "Hopa.Windows.Checks.dll",
    "Hopa.Windows.FakeEngine.dll",
    "Hopa.Windows.IntegrationTests.dll",
    "Hopa.Windows.Tests.dll"
)
foreach ($name in $forbidden) {
    if (Test-Path (Join-Path $stage $name)) {
        throw "developer artifact leaked into the product package: $name"
    }
}

if (-not (Test-Path (Join-Path $stage "Hopa.Windows.exe"))) {
    throw "the product exe is missing from the package"
}

Write-Host "3/5 jlink runtime"
& (Join-Path $jdk "bin/jlink.exe") --add-modules java.base,java.logging,java.net.http,java.desktop,java.management,java.naming,java.security.jgss,jdk.crypto.ec,jdk.crypto.cryptoki,jdk.unsupported,jdk.zipfs --strip-debug --no-header-files --no-man-pages --compress=zip-6 --output (Join-Path $stage "runtime")
if ($LASTEXITCODE -ne 0) { throw "jlink failed" }

$runtimeRelease = Get-Content (Join-Path $stage "runtime/release") -Raw
if ($runtimeRelease -notmatch 'JAVA_VERSION="21\.') {
    throw "The staged runtime is not JDK 21; refusing to package it."
}
Write-Host "runtime: JDK 21"

Write-Host "4/5 zip"
$zip = Join-Path $out "hopa-windows-0.1.0.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
# dotnet publish can leave a build server holding a DLL for a moment. The
# archive is large enough that a retry is cheaper than a flaky package job.
dotnet build-server shutdown 2>$null | Out-Null
for ($attempt = 0; ; $attempt++) {
    try {
        Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force
        break
    }
    catch {
        if ($attempt -ge 2) { throw }
        Write-Warning "zip attempt $($attempt + 1) failed: $($_.Exception.Message)"
        Start-Sleep -Seconds 2
        dotnet build-server shutdown 2>$null | Out-Null
    }
}
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $out "hopa-windows-0.1.0.zip.sha256") -Value $hash -Encoding ascii
Write-Host "zip: $zip"
Write-Host "sha256: $hash"

Write-Host "5/5 msi"
if ($SkipMsi) {
    Write-Host "msi skipped"
    return
}

$wix = Get-Command wix -ErrorAction SilentlyContinue
if ($null -eq $wix) {
    Write-Warning "WiX is not installed; install it with: dotnet tool install --global wix"
    return
}

$msi = Join-Path $out "hopa-windows-0.1.0.msi"
$wxs = Join-Path $root "apps/windows/installer/Hopa.wxs"

$license = Get-Content (Join-Path $root "LICENSE") -Raw
$escaped = $license.Replace('\', '\\').Replace('{', '\{').Replace('}', '\}')
$rtf = "{\rtf1\ansi\deff0{\fonttbl{\f0 Segoe UI;}}\f0\fs18" + (($escaped -split "`r?`n") -join '\par ') + "}"
$licenseRtf = Join-Path $stage "LICENSE.rtf"
Set-Content -Path $licenseRtf -Value $rtf -Encoding ascii

& wix build -ext WixToolset.UI.wixext -d SourceDir="$stage" -d LicenseRtf="$licenseRtf" -o $msi $wxs
if ($LASTEXITCODE -ne 0) { throw "wix build failed" }
$msiHash = (Get-FileHash $msi -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $out "hopa-windows-0.1.0.msi.sha256") -Value $msiHash -Encoding ascii
Write-Host ("msi: {0}" -f $msi)
Write-Host ("msi sha256: {0}" -f $msiHash)
