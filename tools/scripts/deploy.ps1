#!/usr/bin/env pwsh
# Build both HAPs, install each on the connected device it belongs to, restore
# the USB reverse port, relaunch, and drop a screenshot per device.
#
#   powershell -ExecutionPolicy Bypass -File tools\scripts\deploy.ps1
#   ... -SkipBuild        reuse the last build
#   ... -NoLaunch         install + rport only
param(
    [switch]$SkipBuild,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path $hdc)) {
    $cmd = Get-Command hdc -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'hdc not found.' }
    $hdc = $cmd.Source
}

$entry = Join-Path $root 'apps\harmony\phone\build\default\outputs\default\entry-default-signed.hap'
$laptop = Join-Path $root 'apps\harmony\laptop\build\default\outputs\default\laptop-default-signed.hap'
$shots = Join-Path $env:TEMP 'hopa-shots'
New-Item -ItemType Directory -Force $shots | Out-Null

if (-not $SkipBuild) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'tools\scripts\build.ps1')
    if (-not (Test-Path $entry)) { throw 'build did not produce the phone HAP' }
}

$targets = @(& $hdc list targets 2>$null | Where-Object { $_ -match '^\S+' -and $_ -notmatch '\[Empty\]' })
if ($targets.Count -eq 0) { throw 'no device is connected' }

foreach ($t in $targets) {
    $serial = ($t -split '\s+')[0]
    $kind = (& $hdc -t $serial shell 'param get const.product.devicetype' 2>$null) -join ''
    $isLaptop = $kind -match '2in1'

    $hap = if ($isLaptop) { $laptop } else { $entry }
    $ability = if ($isLaptop) { 'LaptopAbility' } else { 'EntryAbility' }
    $label = if ($isLaptop) { 'laptop' } else { 'phone' }

    Write-Host "== $label $serial =="
    $installed = & $hdc -t $serial install -r $hap 2>&1 | Select-String -Pattern 'successfully|failed'
    Write-Host ("  install: " + ($installed -join ' ').Trim())

    # install drops the reverse tunnel; the bridge is unreachable without it
    & $hdc -t $serial rport tcp:8766 tcp:8766 2>&1 | Out-Null

    if (-not $NoLaunch) {
        & $hdc -t $serial shell "aa force-stop com.hopa.agent" 2>&1 | Out-Null
        & $hdc -t $serial shell "aa start -a $ability -b com.hopa.agent" 2>&1 | Out-Null
        Start-Sleep -Seconds 5
    }

    $remote = '/data/local/tmp/hopa-smoke.jpeg'
    & $hdc -t $serial shell "snapshot_display -f $remote" 2>&1 | Out-Null
    $local = Join-Path $shots "$label.jpeg"
    & $hdc -t $serial file recv $remote $local 2>&1 | Out-Null
    if (Test-Path $local) { Write-Host "  screenshot: $local" }
}

Write-Host "done"
