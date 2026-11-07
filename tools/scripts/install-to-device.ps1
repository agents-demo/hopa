#!/usr/bin/env pwsh
# Install the built HAP on the connected emulator/device and launch it (Windows).
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$app = Join-Path $root 'apps\harmony'
$out = Join-Path $app 'entry\build\default\outputs\default'
$bundle = 'com.hopa.agent'
$ability = 'EntryAbility'

function Resolve-Hdc {
    if ($env:HOPA_CLT_HOME) {
        foreach ($name in @('hdc.exe', 'hdc')) {
            $candidate = Join-Path $env:HOPA_CLT_HOME "sdk\default\openharmony\toolchains\$name"
            if (Test-Path $candidate) { return $candidate }
        }
    }
    $cmd = Get-Command hdc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'hdc not found. Set HOPA_CLT_HOME or add the toolchains directory to PATH.'
}

$hdc = Resolve-Hdc

$hap = Get-ChildItem $out -Filter '*-signed.hap' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $hap) {
    $hap = Get-ChildItem $out -Filter '*.hap' -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $hap) {
    throw "No HAP found in $out. Run scripts/build.ps1 first."
}

Write-Host '--- targets ---'
& $hdc list targets
if ($LASTEXITCODE -ne 0) { throw 'hdc list targets failed' }

Write-Host "--- installing $($hap.Name) ---"
& $hdc install -r $hap.FullName
if ($LASTEXITCODE -ne 0) { throw 'hdc install failed' }

Write-Host "--- launching $bundle/$ability ---"
& $hdc shell aa start -a $ability -b $bundle
if ($LASTEXITCODE -ne 0) { throw 'launch failed' }
