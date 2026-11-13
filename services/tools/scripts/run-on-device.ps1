#!/usr/bin/env pwsh
# Build, sign, install and launch HOPA on the connected emulator/device (Windows).
#
#   .\tools\scripts\run-on-device.ps1                       # full cycle
#   .\tools\scripts\run-on-device.ps1 -SkipBuild            # reuse the last build
#   .\tools\scripts\run-on-device.ps1 -Target 127.0.0.1:5555
#   .\tools\scripts\run-on-device.ps1 -SkipSign             # reuse the signed HAP
#
# The debug profile embeds the target's UDID, so the script reads it from the
# selected device before signing. Nothing leaves the machine.
param(
    [switch]$SkipBuild,
    [switch]$SkipSign,
    [string]$Target = '',
    [string]$BundleName = 'com.hopa.agent',
    [string]$Ability = 'EntryAbility'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$app = Join-Path $root 'apps\harmony'
$out = Join-Path $app 'entry\build\default\outputs\default'
$signed = Join-Path $out 'entry-default-signed.hap'
$unsigned = Join-Path $out 'entry-default-unsigned.hap'

if (-not $env:HOPA_CLT_HOME) {
    $clt = 'C:\HarmonyOS\command-line-tools'
    if (Test-Path (Join-Path $clt 'bin\hvigorw.bat')) { $env:HOPA_CLT_HOME = $clt }
}

function Resolve-Hdc {
    # The Command Line Tools hdc 3.2.0d crashes on `install` (missing DLL), so
    # prefer DevEco's bundled copy when it exists.
    $candidates = @(
        'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
    )
    if ($env:HOPA_CLT_HOME) {
        $candidates += Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains\hdc.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command hdc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'hdc not found. Set HOPA_CLT_HOME or add the toolchains directory to PATH.'
}

$hdc = Resolve-Hdc

function Invoke-Hdc {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $hdc @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if (-not $AllowFailure -and $code -ne 0) {
        Write-Host $output.Trim()
        throw "hdc $($Arguments -join ' ') failed with exit code $code"
    }
    return $output
}

# --- pick a target ---------------------------------------------------------
if (-not $Target) {
    $listed = @((Invoke-Hdc -Arguments @('list', 'targets')).Trim() -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^\[Empty\]$' })
    if ($listed.Count -eq 0) {
        throw 'No device/emulator connected. Start the emulator or connect USB, then check `hdc list targets`.'
    }
    if ($listed.Count -gt 1) {
        throw "More than one target connected ($($listed -join ', ')). Pass -Target <id>."
    }
    $Target = $listed[0]
}
Write-Host "Target: $Target"

# --- build ----------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host '=== build ==='
    & (Join-Path $root 'tools\scripts\build.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'build failed' }
}
if (-not (Test-Path $unsigned)) {
    throw "Unsigned HAP not found: $unsigned. Run without -SkipBuild first."
}

# --- sign -----------------------------------------------------------------
if (-not $SkipSign) {
    Write-Host '=== sign ==='
    $udidOutput = Invoke-Hdc -Arguments @('-t', $Target, 'shell', 'bm', 'get', '--udid') -AllowFailure
    $match = [regex]::Match($udidOutput, '[0-9A-Fa-f]{64}')
    if (-not $match.Success) {
        throw "Could not read the device UDID from '$Target'. Output: $($udidOutput.Trim())"
    }
    & (Join-Path $root 'tools\scripts\sign-app.ps1') -Udids @($match.Value) -BundleName $BundleName
    if ($LASTEXITCODE -ne 0) { throw 'signing failed' }
}
if (-not (Test-Path $signed)) {
    throw "Signed HAP not found: $signed. Run without -SkipSign first."
}

# --- install --------------------------------------------------------------
Write-Host '=== install ==='
$installOutput = Invoke-Hdc -Arguments @('-t', $Target, 'install', '-r', $signed)
Write-Host $installOutput.Trim()

# --- launch ---------------------------------------------------------------
Write-Host "=== launch $BundleName/$Ability ==="
$launchOutput = Invoke-Hdc -Arguments @('-t', $Target, 'shell', 'aa', 'start', '-a', $Ability, '-b', $BundleName)
Write-Host $launchOutput.Trim()
if ($launchOutput -notmatch 'success') {
    throw 'launch did not report success'
}

Write-Host ''
Write-Host "HOPA is running on $Target."
