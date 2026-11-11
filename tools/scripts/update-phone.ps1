#!/usr/bin/env pwsh
# Build, install and launch HOPA on the phone. It does not start the PC agent;
# run tools\scripts\run-agent.ps1 for the bridge and cloud link.
#
#   .\tools\scripts\update-phone.ps1
#   .\tools\scripts\update-phone.ps1 -SkipBuild
#   .\tools\scripts\update-phone.ps1 -NoLaunch
#   .\tools\scripts\update-phone.ps1 -KeepAccessibility
#
# By default the accessibility extension is stripped for the build (retail
# HarmonyOS refuses to install it without the vendor ACL) and the manifest is
# restored from git afterwards. Use -KeepAccessibility for an ACL-enabled or
# emulator build.
param(
    [switch]$SkipBuild,
    [switch]$NoLaunch,
    [switch]$KeepAccessibility,
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$envPath = Join-Path $root $EnvFile
if (-not (Test-Path $envPath)) { throw "Config file not found: $envPath" }

$cfg = @{}
Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#') -or -not $line.Contains('=')) { return }
    $index = $line.IndexOf('=')
    $key = $line.Substring(0, $index).Trim()
    $value = $line.Substring($index + 1).Trim()
    if ($value.Length -ge 2) {
        $first = $value.Substring(0, 1)
        $last = $value.Substring($value.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    $cfg[$key] = $value
}

$required = @('HOPA_MODEL_BASE_URL', 'HOPA_MODEL_NAME', 'HOPA_MODEL_API_KEY', 'HOPA_BRIDGE_URL', 'HOPA_BRIDGE_TOKEN')
$missing = @($required | Where-Object { -not $cfg[$_] })
if ($missing.Count -gt 0) {
    throw "Fill these in $EnvFile first: $($missing -join ', ')"
}

function Resolve-Hdc {
    $candidates = @(
        'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
    )
    if ($env:HOPA_CLT_HOME) {
        $candidates += Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains\hdc.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $command = Get-Command hdc -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'hdc not found. Set HOPA_CLT_HOME or add the toolchains directory to PATH.'
}

$hdc = Resolve-Hdc
$target = $cfg['HOPA_DEVICE']
if (-not $target) {
    $listed = @((& $hdc list targets 2>&1 | Out-String).Trim() -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^\[Empty\]$' })
    if ($listed.Count -ne 1) {
        throw "Connect exactly one device or set HOPA_DEVICE in $EnvFile."
    }
    $target = $listed[0]
}

$app = Join-Path $root 'apps\harmony'
$manifest = Join-Path $app 'phone\src\main\module.json5'
$manifestRel = 'apps/harmony/phone/src/main/module.json5'
$hap = Join-Path $app 'phone\build\default\outputs\default\entry-default-signed.hap'

if (-not $SkipBuild) {
    if ($KeepAccessibility) {
        Write-Host 'Building with the accessibility extension (needs the vendor ACL).'
        & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'tools\scripts\build.ps1')
        if ($LASTEXITCODE -ne 0) { throw "build failed with exit code $LASTEXITCODE" }
    } else {
        & git -C $root ls-files --error-unmatch $manifestRel 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "$manifestRel is not tracked, so it cannot be restored." }
        & git -C $root diff --quiet -- $manifestRel
        if ($LASTEXITCODE -ne 0) {
            throw "$manifestRel has uncommitted changes; commit or stash them before a retail build."
        }
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & python (Join-Path $root 'tools\scripts\strip-accessibility.py') $manifest
            if ($LASTEXITCODE -ne 0) { throw 'strip-accessibility failed' }
            & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'tools\scripts\build.ps1')
            if ($LASTEXITCODE -ne 0) { throw "build failed with exit code $LASTEXITCODE" }
        } finally {
            # Always put the dev manifest back, even when the build fails.
            & git -C $root checkout -- $manifestRel
            $ErrorActionPreference = $previous
        }
    }
}

if (-not (Test-Path $hap)) { throw "HAP not found: $hap" }

Write-Host "== phone $target =="
& $hdc -t $target shell aa force-stop com.hopa.agent 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
$installOutput = & $hdc -t $target install -r $hap 2>&1 | Out-String
Write-Host ("  install: " + $installOutput.Trim())
if ($LASTEXITCODE -ne 0 -or $installOutput -notmatch 'successfully') {
    throw 'The install did not report success.'
}

$phoneUrl = $cfg['HOPA_BRIDGE_URL']
$isLoopback = $phoneUrl -match '^https?://(127\.0\.0\.1|localhost)(:|/|$)'
if ($isLoopback) {
    # A local address only works over the USB reverse tunnel, which the
    # install just dropped.
    $uri = [Uri]$phoneUrl
    $port = if ($uri.Port -gt 0) { $uri.Port } else { 80 }
    & $hdc -t $target rport "tcp:$port" "tcp:$port" 2>&1 | Out-Null
} else {
    Write-Host '  cloud mode: run tools\scripts\run-agent.ps1 to keep the relay link up.'
}

if ($NoLaunch) {
    Write-Host 'installed; launch skipped (-NoLaunch)'
    exit 0
}

$parameters = [ordered]@{
    'hopa.provider'     = $cfg['HOPA_MODEL_PROVIDER']
    'hopa.base_url'     = $cfg['HOPA_MODEL_BASE_URL']
    'hopa.model'        = $cfg['HOPA_MODEL_NAME']
    'hopa.api_key'      = $cfg['HOPA_MODEL_API_KEY']
    'hopa.bridge_url'   = $phoneUrl
    'hopa.bridge_token' = $cfg['HOPA_BRIDGE_TOKEN']
}
$shellArgs = @('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.hopa.agent')
foreach ($key in $parameters.Keys) {
    $value = $parameters[$key]
    if ($value) {
        $shellArgs += '--ps'
        $shellArgs += $key
        $shellArgs += ("'" + $value.Replace("'", "'\''") + "'")
    }
}

$launchOutput = & $hdc -t $target @shellArgs 2>&1 | Out-String
if ($launchOutput -notmatch 'success') {
    Write-Host $launchOutput.Trim()
    throw 'Failed to launch HOPA with the .env settings.'
}
Write-Host "launched com.hopa.agent against $phoneUrl"
