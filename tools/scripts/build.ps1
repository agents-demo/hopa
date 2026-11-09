#!/usr/bin/env pwsh
# Build the HOPA HAP with DevEco Studio or the Command Line Tools (Windows).
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$app = Join-Path $root 'apps\harmony'
$dev = 'C:\Program Files\Huawei\DevEco Studio'
$hvigorw = $null

if ($env:HOPA_CLT_HOME) {
    $candidate = Join-Path $env:HOPA_CLT_HOME 'bin\hvigorw.bat'
    if (Test-Path $candidate) {
        $hvigorw = $candidate
        $env:DEVECO_SDK_HOME = Join-Path $env:HOPA_CLT_HOME 'sdk'
        $env:PATH = "$(Join-Path $env:HOPA_CLT_HOME 'bin');$(Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains');$env:PATH"
    }
}

if (-not $hvigorw) {
    $candidate = Join-Path $dev 'tools\hvigor\bin\hvigorw.bat'
    if (Test-Path $candidate) {
        $hvigorw = $candidate
        $env:DEVECO_SDK_HOME = Join-Path $dev 'sdk'
        $env:JAVA_HOME = Join-Path $dev 'jbr'
        $env:PATH = "$(Join-Path $dev 'tools\node');$(Join-Path $dev 'tools\ohpm\bin');$(Join-Path $dev 'sdk\default\openharmony\toolchains');$env:PATH"
    }
}

if (-not $hvigorw) {
    $cmd = Get-Command hvigorw -ErrorAction SilentlyContinue
    if ($cmd) { $hvigorw = $cmd.Source }
}
if (-not $hvigorw) {
    throw 'hvigorw not found. Set HOPA_CLT_HOME or add the DevEco/Command Line Tools bin directory to PATH.'
}

# Packaging (PackageHap) shells out to `java`, so make sure a JRE is on PATH.
$javaHome = $env:JAVA_HOME
if (-not $javaHome) {
    $devJbr = Join-Path $dev 'jbr'
    if (Test-Path (Join-Path $devJbr 'bin\java.exe')) { $javaHome = $devJbr }
}
if ($javaHome -and (Test-Path (Join-Path $javaHome 'bin\java.exe'))) {
    $env:JAVA_HOME = $javaHome
    $env:PATH = "$(Join-Path $javaHome 'bin');$env:PATH"
}

Push-Location $app
$previous = $ErrorActionPreference
# hvigor/ohpm log INFO and WARN to stderr; with EAP=Stop PowerShell turns
# those into terminating NativeCommandError records. Judge by exit code instead.
$ErrorActionPreference = 'Continue'
try {
    $ohpm = Get-Command ohpm -ErrorAction SilentlyContinue
    if ($ohpm) {
        & $ohpm.Source install
        if ($LASTEXITCODE -ne 0) { throw 'ohpm install failed' }
    }

    & $hvigorw assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "hvigorw failed with exit code $LASTEXITCODE" }

    $outs = @(
        (Join-Path $app 'phone\build\default\outputs\default'),
        (Join-Path $app 'laptop\build\default\outputs\default')
    )
    foreach ($out in $outs) {
        if (Test-Path $out) {
            Get-ChildItem $out -Filter '*.hap' | ForEach-Object { Write-Host "Built: $($_.FullName)" }
        }
    }
} finally {
    $ErrorActionPreference = $previous
    Pop-Location
}
